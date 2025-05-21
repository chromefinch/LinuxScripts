#!/usr/bin/env bash
# Script to add multiple IP addresses to a network interface using nmcli

# --- Configuration & Setup ---
# Ascii art header
cat <<'EOF'
    _______________                           |*\_/*|________
  |  ___________  |     .-.     .-.     ||_/-\_|______  |
  | |           | |    .****. .****.    | |           | |
  | |   0   0   | |    .*****.*****.    | |   0   0   | |
  | |     -     | |     .*********.     | |     -     | |
  | |   \___/   | |      .*******.      | |   \___/   | |
  | |___     ___| |       .*****.       | |___________| |
  |_____|\_/|_____|        .***.        |_______________|
    _|__|/ \|_|_.............*.............._|________|_
   / ********** \                         / ********** \
 / ************ \                       / ************ \
--------------------                    --------------------
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
print_purple "MoreIPsPlease (nmcli Edition) - IP Address Configuration Tool"
print_purple "This script uses NetworkManager (nmcli) to configure IPs."

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

# --- Determine Network Interface and User ---
print_blue "Determining default network interface..."
IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

if [ -z "$IFACE" ]; then
    print_red "Could not automatically determine the network interface via default route."
    print_yellow "Please ensure you have a default route configured or manually specify the interface."
    exit 1
fi
print_green "Detected network interface: $IFACE"

# Get the original user if sudo was used
userid=$SUDO_USER
if [ -z "$userid" ]; then
    userid=$(whoami) # Fallback if not using sudo or SUDO_USER is not set
fi

# --- Get NetworkManager Connection ID for the Interface ---
print_blue "Attempting to find NetworkManager connection profile for $IFACE..."
CON_ID=""
# Try to get the UUID of the active connection on the interface
# The grep pattern ensures we match the exact interface name
ACTIVE_CON_ID=$(nmcli -t -f UUID,DEVICE connection show --active | grep -E "(^|:)${IFACE}($|:)" | head -n1 | cut -d':' -f1)

if [ -n "$ACTIVE_CON_ID" ]; then
    CON_ID="$ACTIVE_CON_ID"
    print_green "Found active connection for $IFACE."
else
    print_yellow "No active connection found for $IFACE. Trying to find any configured connection for this device..."
    # Try to get the UUID of any configured (even inactive) connection for the interface
    CONFIGURED_CON_ID=$(nmcli -t -f UUID,DEVICE connection show | grep -E "(^|:)${IFACE}($|:)" | head -n1 | cut -d':' -f1)
    if [ -n "$CONFIGURED_CON_ID" ]; then
        CON_ID="$CONFIGURED_CON_ID"
        print_yellow "Found configured (but possibly inactive) connection for $IFACE."
    fi
fi

if [ -z "$CON_ID" ]; then
    print_red "No NetworkManager connection profile found associated with interface $IFACE."
    print_red "This script requires an existing NetworkManager connection profile for the interface."
    print_yellow "You can list connections with 'nmcli connection show'."
    print_yellow "If $IFACE is unmanaged by NetworkManager, this script won't work as intended."
    print_yellow "Consider creating a connection profile or ensuring NetworkManager manages $IFACE."
    exit 1
else
    CON_NAME=$(nmcli -t -f NAME,UUID connection show | grep "$CON_ID" | head -n1 | cut -d':' -f1)
    print_green "Using NetworkManager connection: '$CON_NAME' (UUID: $CON_ID) for interface $IFACE"
fi

# --- Script Usage and Input Validation ---
echo "This script configures multiple IPs on '$IFACE' using NetworkManager profile '$CON_NAME'."
echo "It assumes a /24 address space and will set the IPv4 method to manual."

if [ -z "$1" ] || [ -z "$2" ]; then
    print_yellow "Please provide a starting IP address and the TOTAL number of IPs to configure."
    echo "Example: ./MoreIPsPlease_nmcli.sh 192.168.1.50 100"
    echo "This will configure IPs from 192.168.1.50 up to 192.168.1.149 (100 IPs)."
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

# --- Gateway Detection Logic ---
print_blue "Detecting gateway..."
gateway=$(ip route | grep '^default' | grep "dev $IFACE" | awk '{print $3}' | head -n1)
if [ -z "$gateway" ]; then
    # Broader search if not found on specific IFACE
    gateway=$(ip route | grep '^default' | awk '{print $3}' | head -n1)
fi

# If gateway is still not found, try legacy methods
if [ -z "$gateway" ]; then
    print_red "Could not determine gateway using 'ip route'. Please check your network configuration."
    gateway_legacy=$(route -n | grep 'UG[ \t]' | grep "$IFACE" | awk '{print $2}' | head -n1)
    if [ -z "$gateway_legacy" ]; then # Check if first legacy attempt failed
        gateway_legacy=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | head -n1) # Broader legacy attempt
    fi

    if [ -n "$gateway_legacy" ]; then
        print_yellow "Falling back to legacy route command for gateway: $gateway_legacy"
        gateway=$gateway_legacy
    else
        print_red "Still could not determine gateway. You may need to set it manually after running."
        # Allow proceeding without gateway if user confirms
        read -p "Proceed without a gateway defined for NetworkManager? (y/N): " confirm_no_gw < /dev/tty
        if [[ ! "$confirm_no_gw" =~ ^[yY]([eE][sS])?$ ]]; then
            print_red "Exiting due to missing gateway."
            exit 1
        fi
        gateway="" # Explicitly empty
    fi
fi

if [ -n "$gateway" ]; then
    print_green "Detected Gateway: $gateway"
else
    print_yellow "Warning: Proceeding without a defined gateway for NetworkManager."
fi
# --- End of Gateway Detection Logic ---

# --- Construct the list of IP addresses ---
print_blue "Constructing list of IP addresses to configure..."
ip_list_for_nmcli="" # Initialize as empty
first_three_octets=$(echo "$START_IP" | cut -d '.' -f 1,2,3)
last_Octet_start=$(echo "$START_IP" | awk -F"." '{print $4}')

for i in $(seq 0 $((NUM_IPS - 1)) ); do
    current_octet=$((last_Octet_start + i))
    if [ "$current_octet" -lt 1 ] || [ "$current_octet" -gt 254 ]; then # Check valid range for host part
        print_yellow "Warning: Skipping IP $first_three_octets.$current_octet as octet ($current_octet) is outside valid range 1-254."
        continue
    fi
    current_ip_with_prefix="$first_three_octets.$current_octet/24"

    if [ -z "$ip_list_for_nmcli" ]; then # For the first valid IP
        ip_list_for_nmcli="$current_ip_with_prefix"
    else # For subsequent valid IPs, use comma as separator
        ip_list_for_nmcli="$ip_list_for_nmcli,$current_ip_with_prefix"
    fi
done

if [ -z "$ip_list_for_nmcli" ]; then
    print_red "No valid IP addresses were constructed. Exiting."
    exit 1
fi

print_green "IPs to be configured on '$CON_NAME': $ip_list_for_nmcli"

# --- Display Proposed Changes and Confirmation ---
echo ""
print_purple "--- NetworkManager Configuration Summary ---"
print_blue "Interface:         $IFACE"
print_blue "Connection Profile: '$CON_NAME' (UUID: $CON_ID)"
print_blue "IPv4 Method:       manual"
print_blue "IP Addresses:      $ip_list_for_nmcli"
if [ -n "$gateway" ]; then
    print_blue "Gateway:           $gateway"
else
    print_yellow "Gateway:           (Not Set)"
fi
echo "----------------------------------------"
echo ""

read -t 20 -p "Does the above look correct (y/N)? You have 20 seconds: " yn < /dev/tty
echo ""

# --- Apply Changes or Cancel ---
case $yn in
    [yY] | [yY][eE][sS] )
        print_green "Proceeding with NetworkManager configuration..."

        print_yellow "Modifying NetworkManager connection '$CON_NAME'..."
        
        # Prepare gateway argument for nmcli
        gateway_arg=""
        if [ -n "$gateway" ]; then
            gateway_arg="ipv4.gateway $gateway"
        else # If no gateway, explicitly clear it in NM profile to avoid lingering old gateway
            gateway_arg="ipv4.gateway ''"
        fi

        # --- DEBUGGING LINES ---
        print_yellow "-----------------------------------------------------"
        print_yellow "DEBUG: About to modify connection."
        print_yellow "DEBUG: CON_ID used by script: [$CON_ID]"
        print_yellow "DEBUG: CON_NAME derived by script: [$CON_NAME]"
        print_yellow "DEBUG: IFACE detected: [$IFACE]"
        print_yellow "DEBUG: ip_list_for_nmcli: [$ip_list_for_nmcli]"
        print_yellow "DEBUG: gateway_arg: [$gateway_arg]"
        print_yellow "DEBUG: Full nmcli modify command (before sudo) would be:"
        print_yellow "nmcli connection modify \"$CON_ID\" ipv4.method manual ipv4.addresses \"$ip_list_for_nmcli\" $gateway_arg"
        print_yellow "-----------------------------------------------------"
        # --- END OF DEBUGGING LINES ---

        # Modify the connection: set to manual, assign all IPs, and set/clear gateway
        # This command replaces existing ipv4.addresses with the new list.
        if sudo nmcli connection modify "$CON_ID" ipv4.method manual ipv4.addresses "$ip_list_for_nmcli" $gateway_arg; then
            print_green "Connection profile '$CON_NAME' modified successfully."
            
            print_yellow "Attempting to reapply configuration to $IFACE..."
            if sudo nmcli device reapply "$IFACE"; then
                print_green "Configuration reapplied to $IFACE successfully."
            elif sudo nmcli connection up "$CON_ID" ifname "$IFACE"; then # Fallback
                print_green "Connection '$CON_NAME' activated on $IFACE successfully."
            else
                print_red "Failed to reapply or activate connection on $IFACE."
                print_yellow "Check 'nmcli device status' and 'nmcli connection show \"$CON_NAME\"'."
                print_yellow "You might need to manually run: sudo nmcli connection up \"$CON_ID\" ifname \"$IFACE\""
                print_yellow "Or ensure NetworkManager is controlling $IFACE (check /etc/NetworkManager/NetworkManager.conf)."
            fi
        else
            print_red "Failed to modify NetworkManager connection profile '$CON_NAME'." 
            print_yellow "Check permissions and NetworkManager status ('systemctl status NetworkManager')."
            print_yellow "Also check the exact error message from nmcli above this line for clues."
        fi

        echo ""
        print_blue "Current IP configuration (from 'ip -c addr show dev $IFACE'):"
        ip -c addr show dev "$IFACE"
        echo ""
        print_blue "NetworkManager connection details for '$CON_NAME':"
        nmcli connection show "$CON_ID" | grep -Eo "ipv4.addresses: .*"

        print_green "[+] Done!"
        ;;
    * )
        print_yellow "No action taken. NetworkManager configuration not changed."
        exit 0
        ;;
esac

exit 0
