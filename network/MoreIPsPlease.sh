#!/usr/bin/env bash
# Script to add multiple IP addresses to a network interface

# --- Configuration & Setup ---
# Ascii art header
cat <<'EOF'
   _______________                        |*\_/*|________
  |  ___________  |     .-.     .-.      ||_/-\_|______  |
  | |           | |    .****. .****.     | |           | |
  | |   0   0   | |    .*****.*****.     | |   0   0   | |
  | |     -     | |     .*********.      | |     -     | |
  | |   \___/   | |      .*******.       | |   \___/   | |
  | |___     ___| |       .*****.        | |___________| |
  |_____|\_/|_____|        .***.         |_______________|
    _|__|/ \|_|_.............*.............._|________|_
   / ********** \                          / ********** \
 /  ************  \                      /  ************  \
--------------------                    --------------------
EOF

# --- Helper Functions for Colored Output ---
print_green (){
	echo -e "\033[0;32m$1\033[0m"
}
print_yellow (){
	echo -e "\033[0;33m$1\033[0m"
}
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
print_blue (){
	echo -e "\033[0;34m$1\033[0m"
}
print_purple (){
	echo -e "\033[0;35m$1\033[0m"
}

# --- Script Information ---
print_purple "MoreIPsPlease - IP Address Configuration Tool"

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root or with sudo."
   exit 1
fi

# --- Determine Network Interface and User ---
# Get the interface name associated with the default route
# This assumes there's one primary outbound interface.
IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

if [ -z "$IFACE" ]; then
    print_red "Could not automatically determine the network interface."
    print_yellow "Please ensure you have a default route configured."
    # Fallback: list available interfaces (excluding loopback and common virtual ones)
    print_yellow "Available interfaces (excluding lo, docker, veth, virbr):"
    ls /sys/class/net/ | grep -Ev '^(lo|docker.*|veth.*|virbr.*|br-.*)'
    print_yellow "You might need to manually specify the interface in the script."
    exit 1
fi
print_blue "Detected network interface: $IFACE"

# Get the original user if sudo was used, for backup path
userid=$SUDO_USER
if [ -z "$userid" ]; then
    userid=$(whoami) # Fallback if not using sudo or SUDO_USER is not set
fi


# --- Script Usage and Input Validation ---
echo "This script assumes a /24 address space and modifies the '$IFACE' interface."
echo "It also sets the primary IP as static (DHCP configuration will be commented out)."
echo "Primarily intended for systems like Kali Linux during exercises."

if [ -z "$1" ] || [ -z "$2" ]; then
    print_yellow "Please provide a starting IP address and the number of additional IPs to iterate."
    echo "Example: ./MoreIPsPlease.sh 192.168.1.50 100"
    echo "This will configure IPs from 192.168.1.50 up to 192.168.1.149 (100 IPs in total, including the start IP)."
    echo "Note: The second argument is the TOTAL number of IPs, including the start IP."
    echo "If you want 100 *additional* IPs, and 192.168.1.50 is the first, the last would be .149."
    echo "So, for 100 IPs starting at .50, the iteration count is 100."
    exit 1
fi

# Validate the number of IPs argument
if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ]; then
    print_red "Error: Number of IPs must be a positive integer."
    exit 1
fi

# --- Network Configuration Details ---
START_IP=$1
NUM_IPS=$2

# Validate START_IP format (basic check)
if ! [[ "$START_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_red "Error: Invalid start IP address format: $START_IP"
    exit 1
fi

gateway=$(ip route | grep '^default' | awk '{print $3}' | head -n1)
if [ -z "$gateway" ]; then
    print_red "Could not determine gateway. Please check your network configuration."
    # Attempt legacy route command if ip route fails for gateway
    gateway_legacy=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | head -n1)
    if [ -n "$gateway_legacy" ]; then
        print_yellow "Falling back to legacy route command for gateway: $gateway_legacy"
        gateway=$gateway_legacy
    else
        print_red "Still could not determine gateway. Exiting."
        exit 1
    fi
fi
print_blue "Detected Gateway: $gateway"

# Get current IP of the detected interface (for informational purposes, not used in config generation)
currentIP_on_interface=$(ip -4 addr show dev "$IFACE" | grep -oP 'inet \K[\d.]+' | head -n1)
if [ -n "$currentIP_on_interface" ]; then
    print_blue "Current primary IP on $IFACE: $currentIP_on_interface"
else
    print_yellow "No current IPv4 address found on $IFACE."
fi


echo "IP range to populate:"
last_Octet_start=$(echo "$START_IP" | awk -F"." '{print $4}')
# The loop will run NUM_IPS times. If NUM_IPS is 1, it just sets the START_IP.
# The final octet will be last_Octet_start + NUM_IPS - 1.
final_octet_val=$((last_Octet_start + NUM_IPS - 1))

if [ "$final_octet_val" -gt 254 ]; then
    print_red "Error: The calculated final octet ($final_octet_val) exceeds 254."
    print_red "This might lead to an invalid IP address in a /24 subnet."
    print_yellow "Please adjust the start IP or the number of IPs."
    exit 1
fi

first_three_octets=$(echo "$START_IP" | cut -d '.' -f 1,2,3)
print_blue "$START_IP to $first_three_octets.$final_octet_val"

# --- Generate Temporary Interface Configuration File ---
TMP_INTERFACE_FILE="/tmp/MoreIPsPlease_$$.tmp" # Use process ID for uniqueness in /tmp

# Create the temporary file content
# Note: The primary IP is $START_IP. Aliases start from $START_IP + 1.
# The loop for aliases will go up to NUM_IPS - 1 additional IPs.
cat <<EOF > "$TMP_INTERFACE_FILE"
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# Source any configuration fragments
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface ($IFACE)
auto $IFACE
#iface $IFACE inet dhcp # DHCP is commented out as we are setting static IPs
iface $IFACE inet static
        address $START_IP/24
        gateway $gateway
EOF

# Add IP aliases if NUM_IPS > 1
# The first IP is already set as the primary address for $IFACE.
# We need to add (NUM_IPS - 1) aliases.
# The aliases will be for IPs from (last_Octet_start + 1) to (last_Octet_start + NUM_IPS - 1)
if [ "$NUM_IPS" -gt 1 ]; then
    print_blue "Adding $NUM_IPS IPs (1 primary + $((NUM_IPS - 1)) aliases) to $IFACE..."
    # The alias number for ifupdown (e.g., eth0:0, eth0:1) is just an identifier.
    # It's common to start it from 0 or 1 for the *first alias*.
    # The IPs themselves are what matter.
    # The loop will iterate (NUM_IPS - 1) times for the additional IPs.
    for i in $(seq 1 $((NUM_IPS - 1)) ); do
        current_alias_octet=$((last_Octet_start + i))
        # Ensure alias octet is valid
        if [ "$current_alias_octet" -gt 254 ]; then
            print_yellow "Warning: Skipping IP alias $first_three_octets.$current_alias_octet as octet > 254"
            continue
        fi
        # Alias number for the interface (e.g., eth0:0, eth0:1).
        # We can use 'i-1' to start alias numbers from 0 (e.g., $IFACE:0, $IFACE:1, ...)
        alias_num=$((i - 1)) 
        echo "" >> "$TMP_INTERFACE_FILE" # Add a newline for readability
        echo "auto $IFACE:$alias_num" >> "$TMP_INTERFACE_FILE"
        echo "iface $IFACE:$alias_num inet static" >> "$TMP_INTERFACE_FILE"
        echo "        address $first_three_octets.$current_alias_octet/24" >> "$TMP_INTERFACE_FILE"
    done
else
    print_blue "Setting 1 primary IP for $IFACE: $START_IP"
fi


# --- Display Proposed Changes and Confirmation ---
echo ""
print_blue "The following configuration will be written to /etc/network/interfaces:"
echo ""
cat "$TMP_INTERFACE_FILE"
echo ""
# Prompt for confirmation with a timeout
yn=""
prompt_text="Does the above look correct (y/N)? You have 15 seconds: "
# Ensure reading from terminal for interactive prompt with timeout
if read -t 15 -p "$prompt_text" yn_temp < /dev/tty; then
    yn="$yn_temp"
else
    echo # Newline after timeout
    yn="N" # Default to No on timeout
    print_yellow "Timeout reached. Assuming No."
fi
echo "" # Newline after input or timeout message

# --- Apply Changes or Cancel ---
case $yn in
    [yY] | [yY][eE][sS] )
        print_green "Proceeding with changes..."
        
        # Backup current /etc/network/interfaces
        time_stamp=$(date +"%Y%m%d_%H%M%S") # Filesystem-friendly timestamp
        bkpath="/home/$userid/interfaces_backups" # Standardized backup location
        
        print_yellow "Backing up current /etc/network/interfaces to $bkpath/interfaces_as_of_$time_stamp"
        sleep 1 # Brief pause for user to read
        
        if ! test -d "$bkpath"; then
            mkdir -p "$bkpath"
            if [ $? -ne 0 ]; then
                print_red "Error: Could not create backup directory $bkpath."
                print_red "Please check permissions or create it manually."
                rm "$TMP_INTERFACE_FILE"
                exit 1
            fi
            print_green "Backup directory created: $bkpath"
        fi
        
        if cp /etc/network/interfaces "$bkpath/interfaces_as_of_$time_stamp"; then
            print_green "Backup successful."
        else
            print_red "Error: Failed to backup /etc/network/interfaces."
            print_yellow "Proceeding without backup is risky. Aborting."
            rm "$TMP_INTERFACE_FILE"
            exit 1
        fi
        
        print_yellow "Updating IP addresses by writing to /etc/network/interfaces..."
        if sudo cp "$TMP_INTERFACE_FILE" /etc/network/interfaces; then
            print_green "Successfully updated /etc/network/interfaces."
            
            # --- Network Restart Section (Kali Linux Optimized) ---
            print_yellow "Attempting to apply network changes for $IFACE on Kali Linux..."

            # On Kali Linux (which uses systemd), systemctl is the primary tool for service management.
            # The 'networking.service' is typically responsible for interfaces defined in /etc/network/interfaces.
            
            # Try to restart networking.service first.
            if sudo systemctl restart networking.service; then
                print_green "Successfully restarted networking.service."
            else
                print_red "Command 'sudo systemctl restart networking.service' failed."
                print_yellow "This could mean networking.service is not active, masked, or encountered an error during restart."
                print_yellow "Attempting fallback: sudo ifdown $IFACE && sudo ifup $IFACE"
                
                if sudo ifdown "$IFACE" && sudo ifup "$IFACE"; then
                    print_green "Successfully reconfigured $IFACE using ifdown/ifup."
                else
                    print_red "Both 'systemctl restart networking.service' and 'ifdown/ifup $IFACE' failed."
                    print_red "The new IP configuration might not be active."
                    print_yellow "Troubleshooting steps for Kali Linux:"
                    print_yellow "1. Verify the syntax in /etc/network/interfaces for $IFACE and its aliases."
                    print_yellow "2. Check status: sudo systemctl status networking.service"
                    print_yellow "3. Check logs: journalctl -u networking.service -n 50 --no-pager"
                    print_yellow "4. If NetworkManager is installed/active, check its status and logs:"
                    print_yellow "   sudo systemctl status NetworkManager.service"
                    print_yellow "   journalctl -u NetworkManager.service -n 50 --no-pager"
                    print_yellow "5. Ensure $IFACE is not set to be exclusively managed by NetworkManager if you intend to use /etc/network/interfaces."
                    print_yellow "   (e.g., check /etc/NetworkManager/NetworkManager.conf, and potentially remove connection profiles for $IFACE in NetworkManager)."
                fi
            fi
            # --- End of Network Restart Section ---
            
            echo ""
            print_blue "Final IP configuration status:"
            ip -br a
        else
            print_red "Error: Failed to write to /etc/network/interfaces. Check permissions."
        fi
        
        rm "$TMP_INTERFACE_FILE"
        print_green "[+] Done!"
        ;;
    * )
        print_yellow "No action taken. Configuration was not applied."
        print_yellow "Canceling operation."
        rm "$TMP_INTERFACE_FILE" # Clean up temporary file
        exit 0
        ;;
esac

exit 0
