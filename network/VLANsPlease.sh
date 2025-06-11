#!/usr/bin/env bash
# Script to create multiple VLAN sub-interfaces with sequential IPs using nmcli

# --- Configuration & Setup ---
# Ascii art header
cat <<'EOF'
    _______________                        |*\_/*|________
  |  ___________  |      .--.     .--.     ||_/-\_|______  |
  | |           | |     .----.   .----.    | |           | |
  | |   VLAN    | |    .------. .------.   | |   0    0  | |
  | |  Please!  | |     '------'------'    | |     -     | |
  | |           | |      '----.----'       | |   \___/   | |
  | |___     ___| |       '--. --'         | |___________| |
  |_____|\_/|_____|          '.'           |_______________|
    _|__|/ \|_|_..........................._|________|_
   / ********** \                       / ********** \
  /  ************ \                     /  ************ \
--------------------                   --------------------
EOF

# --- Helper Functions for Colored Output ---
print_green() {
    echo -e "\033[0;32m$1\033[0m"
}
print_yellow() {
    echo -e "\033[0;33m$1\033[0m"
}
print_red() {
    echo -e "\033[0;31m$1\033[0m"
}
print_blue() {
    echo -e "\033[0;34m$1\033[0m"
}
print_purple() {
    echo -e "\033[0;35m$1\033[0m"
}

# --- Script Information ---
print_purple "VLANsPlease (nmcli Edition) - VLAN Sub-interface Configuration Tool"
print_purple "This script uses NetworkManager (nmcli) to create and configure VLANs."

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
    print_red "This script must be run as root or with sudo."
    exit 1
fi

# --- Check if nmcli is available ---
if ! command -v nmcli &> /dev/null; then
    print_red "nmcli command not found. Please install NetworkManager."
    exit 1
fi
print_green "NetworkManager (nmcli) found."

# --- Select Parent Network Interface ---
print_blue "Please select the parent network interface for the new VLANs:"
# Get a list of potential physical interfaces from nmcli, excluding common virtual types.
mapfile -t AVAILABLE_IFACES < <(nmcli -g DEVICE,TYPE device status | grep -vE ':(vlan|bridge|bond|lo|tun|virbr)' | cut -d: -f1)

if [ ${#AVAILABLE_IFACES[@]} -eq 0 ]; then
    print_red "No suitable parent interfaces found by nmcli."
    print_yellow "Exiting. Ensure physical interfaces are managed by NetworkManager."
    exit 1
fi

# Use the 'select' command to create a menu for the user
select IFACE in "${AVAILABLE_IFACES[@]}"; do
    if [[ -n "$IFACE" ]]; then
        print_green "Selected parent interface: $IFACE"
        break
    else
        print_red "Invalid selection. Please enter the number corresponding to the desired interface."
    fi
done

if [ -z "$IFACE" ]; then
    print_red "No interface was selected. Exiting script."
    exit 1
fi


# --- Get User Input for VLAN and IP Configuration ---
echo ""
print_yellow "Please provide the configuration details for the new VLANs."

# Get VLAN IDs
read -p "Enter a space-separated list of VLAN IDs (e.g., 10 20 30): " -a VLAN_IDS
if [ ${#VLAN_IDS[@]} -eq 0 ]; then
    print_red "No VLAN IDs provided. Exiting."
    exit 1
fi

# Get Starting IP Address
read -p "Enter the starting IP address for the first VLAN: " START_IP
if ! [[ "$START_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_red "Error: Invalid start IP address format: $START_IP"
    exit 1
fi

# Get Subnet Prefix (CIDR)
read -p "Enter the subnet prefix (CIDR, e.g., 24): " PREFIX
if ! [[ "$PREFIX" =~ ^[0-9]+$ ]] || [ "$PREFIX" -lt 1 ] || [ "$PREFIX" -gt 32 ]; then
    print_red "Error: Subnet prefix must be an integer between 1 and 32."
    exit 1
fi

# Get Gateway (Optional)
read -p "Enter the gateway IP address (optional, press Enter to skip): " GATEWAY
if [ -n "$GATEWAY" ] && ! [[ "$GATEWAY" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_red "Error: Invalid gateway IP address format. It will be ignored."
    GATEWAY=""
fi


# --- Display Proposed Changes and Confirmation ---
echo ""
print_purple "--- VLAN Configuration Summary ---"
print_blue "Parent Interface:   $IFACE"
if [ -n "$GATEWAY" ]; then
    print_blue "Gateway for all VLANs: $GATEWAY"
else
    print_yellow "Gateway for all VLANs: (Not Set)"
fi
echo "----------------------------------------------------------------"
printf "%-10s | %-20s | %-20s\n" "VLAN ID" "Interface Name" "IP Address"
echo "----------------------------------------------------------------"

# Prepare for IP calculation
ip_prefix=$(echo "$START_IP" | cut -d '.' -f 1,2,3)
last_octet_start=$(echo "$START_IP" | awk -F"." '{print $4}')
ip_counter=0

# Store commands for later execution
declare -a COMMANDS_TO_RUN

for vlan_id in "${VLAN_IDS[@]}"; do
    if ! [[ "$vlan_id" =~ ^[0-9]+$ ]] || [ "$vlan_id" -lt 1 ] || [ "$vlan_id" -gt 4094 ]; then
        print_yellow "Warning: Skipping invalid VLAN ID '$vlan_id'. Must be 1-4094."
        continue
    fi

    current_octet=$((last_octet_start + ip_counter))
    if [ "$current_octet" -gt 254 ]; then
        print_red "Error: Calculated IP address octet exceeds 254. Stopping."
        break
    fi

    current_ip="${ip_prefix}.${current_octet}"
    vlan_iface="${IFACE}.${vlan_id}"
    con_name="vlan-${vlan_id}-on-${IFACE}"

    # Print summary row
    printf "%-10s | %-20s | %-20s\n" "$vlan_id" "$vlan_iface" "${current_ip}/${PREFIX}"

    # Store the commands
    COMMANDS_TO_RUN+=("nmcli connection add type vlan con-name \"$con_name\" ifname \"$vlan_iface\" id \"$vlan_id\" dev \"$IFACE\"")
    gateway_arg=$([ -n "$GATEWAY" ] && echo "ipv4.gateway $GATEWAY" || echo "ipv4.gateway ''")
    COMMANDS_TO_RUN+=("nmcli connection modify \"$con_name\" ipv4.method manual ipv4.addresses \"${current_ip}/${PREFIX}\" $gateway_arg")
    COMMANDS_TO_RUN+=("nmcli connection up \"$con_name\"")

    ip_counter=$((ip_counter + 1))
done
echo "----------------------------------------------------------------"
echo ""

# Confirmation
read -t 20 -p "Does the above look correct (y/N)? You have 20 seconds: " yn < /dev/tty
echo ""

# --- Apply Changes or Cancel ---
case $yn in
    [yY] | [yY][eE][sS] )
        print_green "Proceeding with VLAN interface configuration..."
        
        # Execute stored commands
        for cmd in "${COMMANDS_TO_RUN[@]}"; do
            print_yellow "Executing: $cmd"
            if eval "sudo $cmd"; then
                print_green "Command executed successfully."
            else
                print_red "Error executing command. Stopping."
                # Attempt to clean up a potentially failed connection add
                con_name_to_delete=$(echo "$cmd" | grep -oP 'con-name "\K[^"]+')
                if [ -n "$con_name_to_delete" ]; then
                    sudo nmcli connection delete "$con_name_to_delete" &>/dev/null
                fi
                exit 1
            fi
            sleep 1 # Small delay to allow NetworkManager to process
        done

        echo ""
        print_blue "Current IP configuration for parent interface and new VLANs:"
        ip -c addr show dev "$IFACE"
        for vlan_id in "${VLAN_IDS[@]}"; do
             if [[ "$vlan_id" =~ ^[0-9]+$ ]] && [ "$vlan_id" -ge 1 ] && [ "$vlan_id" -le 4094 ]; then
                ip -c addr show dev "${IFACE}.${vlan_id}" 2>/dev/null
             fi
        done
        echo ""
        print_green "[+] Done!"
        ;;
    * )
        print_yellow "No action taken. Network configuration not changed."
        exit 0
        ;;
esac

exit 0
