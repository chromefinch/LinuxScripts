#!/bin/bash
# chmod +x /usr/local/bin/monthly_maintenance.sh
# sudo chown root:root /usr/local/bin/monthly_maintenance.sh
# sudo chmod 700 /usr/local/bin/monthly_maintenance.sh
# sudo crontab -e
# 0 4 1 * * /bin/bash /usr/local/bin/monthly_maintenance.sh
# --- Log File ---
LOG_FILE="/var/log/monthly_maintenance.log"
DOCKER_BLOCKLIST=("nextcloud" "authentik" "wazuh")

{
    echo "=========================================="
    echo "Maintenance started: $(date)"

    # --- 1. Dynamic Docker Project Discovery ---
    echo "--- Discovering Docker Compose projects ---"
    
    # Initialize empty array
    DOCKER_PROJECTS=()

    # Get list of running container IDs
    CONTAINER_IDS=$(docker ps -q)

    if [ -z "$CONTAINER_IDS" ]; then
        echo "No running containers found. Skipping Docker discovery."
    else
        # 1. Get the working dir label from all containers
        # 2. Sort unique paths
        # 3. Read into an array (handles spaces in paths correctly)
        mapfile -t DOCKER_PROJECTS < <(docker inspect --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' $CONTAINER_IDS | sort -u | grep -v '^$')
    fi

    if [ ${#DOCKER_PROJECTS[@]} -eq 0 ]; then
        echo "No Docker Compose projects identified."
    else 
        echo "Found projects at:"
        printf '%s\n' "${DOCKER_PROJECTS[@]}"
    fi

    # --- 2. System Updates ---
    echo "--- Running System Updates ---"
    
    # Set environment to avoid interactive prompts
    export DEBIAN_FRONTEND=noninteractive
    
    # Update repo lists
    apt-get update
    
    # Upgrade packages
    # -y: Automatic yes to prompts
    # -o Dpkg::Options...: Keep existing config files if conflicts arise
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    # Clean up unused dependencies
    apt-get autoremove -y

    # --- 3. Flatpak Maintenance ---
    # Check if flatpak is installed before trying to run it
    if command -v flatpak &> /dev/null; then
        echo "--- Running Flatpak Updates ---"
        
        # Update all installed runtimes and apps (-y for non-interactive)
        flatpak update -y
        
        # Remove unused runtimes (like old Nvidia drivers or Gnome platforms no longer needed)
        echo "--- Cleaning up unused Flatpak runtimes ---"
        flatpak uninstall --unused -y
    else
        echo "Flatpak not found. Skipping."
    fi
    
# --- 4. Update Docker Containers ---
    echo "--- Updating Docker Containers ---"
    
    for project in "${DOCKER_PROJECTS[@]}"; do
        # --- BLOCKLIST CHECK ---
        skip_project=false
        for block_term in "${DOCKER_BLOCKLIST[@]}"; do
            # Check if project path contains the block term (wildcards *...*)
            if [[ "$project" == *"$block_term"* ]]; then
                echo "SKIPPING: $project (Matched blocklist: '$block_term')"
                skip_project=true
                break
            fi
        done

        if [ "$skip_project" = true ]; then
            continue
        fi
        # -----------------------

        if [ -d "$project" ]; then
            echo "Processing: $project"
            cd "$project" || continue
            
            docker compose pull
            docker compose down
            docker compose up -d
        else
            echo "Warning: Path '$project' found in labels but does not exist on disk."
        fi
    done

    # --- 5. Cleanup Docker Artifacts ---
    echo "--- Cleaning up unused Docker images ---"
    echo "--- Skipping ---"
    #docker image prune -f

    echo "Maintenance finished: $(date)"
    echo "=========================================="

} >> "$LOG_FILE" 2>&1
