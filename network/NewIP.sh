#!/usr/bin/env bash

# --- Configuration & Setup ---
# Ascii art header (condensed for brevity in this example, original was long)
red='\033[0;31m'
clear='\033[0m'
echo -e "${red}"
cat <<'EOF'
                                        :::
                                    .*@@@@@@@=
                                 .:*@@*.   :%@@+:
                             #@@@@@@+.       :%@@@@@@=
                             @@-..               ..*@#
                             @@:        @%-        *@#
                             @@=    ** :@@@+  =#   *@*
                             *@%  -@@@.+@%@@-.@@- :@@:
                             :@@-.@@@@%@@:=@**@@% *@#
                              +@%=@@.*@%: +@@@*@%=@@: -%%%%-   -%%%%%%%
                               +@@@%    ::::. =@@@@: .%@@@@=   =@@@@@@@
                                =@@@-##+@% +#:@@@%:
                                 .%@@%@@@@@@:#@@+
                             @@@=   %@@@@@@@@@=  .#*  *@@@@@@@@@:
                             @@@@@=.  -#@@@+:  :#@@*  *@@@@@@@@@:
                             *******=        :*****=  =*********.
                                   ..........   .........    .........
                                  .@@@@@@@@@@: :@@@@@@@@@#  :@@@@@@@@@*
                                  .@@@@@@@@@@: :@@@@@@@@@#  :@@@@@@@@@*
                                   ==========  .=========-  .=========:

                             @@@@@@@@@%. =@@@@@@@@@*  *@@@@@@@@@:
                             @@@@@@@@@%. =@@@@@@@@@*  *@@@@@@@@@:
                             ---------:. .---------:  :---------.
EOF
echo -e "${clear}"

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
print_blue (){ # Added missing blue color function
	echo -e "\033[0;34m$1\033[0m"
}
print_purple (){
	echo -e "\033[0;35m$1\033[0m"
}

# --- Script Information ---
echo "                                                      NewIP - Primary IP Changer"
print_purple "This script modifies the primary IP on an interface, assuming a /24 address space."
print_purple "It's intended for systems like Kali Linux during exercises."
echo ""

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root or with sudo."
   exit 1
fi

# --- Determine Network Interface and User ---
IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

if [ -z "$IFACE" ]; then
    print_red "Could not automatically determine the network interface."
    print_yellow "Please ensure you have a default route configured."
    print_yellow "Available interfaces (excluding lo, docker, veth, virbr):"
    ls /sys/class/net/ | grep -Ev '^(lo|docker.*|veth.*|virbr.*|br-.*)'
    print_yellow "You might need to manually specify the interface in the script."
    exit 1
fi
print_blue "Detected network interface: $IFACE"

userid=$SUDO_USER
if [ -z "$userid" ]; then
    userid=$(whoami)
fi

# --- Network Configuration Details ---
gateway=$(ip route | grep '^default' | awk '{print $3}' | head -n1)
if [ -z "$gateway" ]; then
    print_red "Could not determine gateway using 'ip route'. Attempting legacy 'route -n'."
    gateway_legacy=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | head -n1)
    if [ -n "$gateway_legacy" ]; then
        print_yellow "Using gateway from legacy route command: $gateway_legacy"
        gateway=$gateway_legacy
    else
        print_red "Still could not determine gateway. Please check your network configuration. Exiting."
        exit 1
    fi
fi
print_blue "Detected Gateway: $gateway"

# Get the current primary IP address of the detected interface
currentIP=$(ip -4 addr show dev "$IFACE" | grep -oP 'inet \K[\d.]+' | head -n1)
if [ -z "$currentIP" ]; then
    print_red "Could not determine the current primary IP address for $IFACE."
    print_yellow "Please ensure $IFACE has an IPv4 address configured."
    exit 1
fi
print_blue "Current primary IP on $IFACE: $currentIP"
last_Oct_currentIP=$(echo "$currentIP" | awk -F"." '{print $4}')

# --- Display Available and Burned IPs ---
print_yellow "Gathering IP information from /etc/network/interfaces and current state..."
# Extract "burned" IPs from comments in /etc/network/interfaces
burned_ips_comment=$(grep -E "^#\s*burned\s+" /etc/network/interfaces | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' || true)

# Get all IPs currently configured on the system (for the specific interface and its aliases)
# This includes the primary IP and any aliases like $IFACE:0, $IFACE:1 etc.
all_configured_ips_on_iface=$(ip -4 addr show dev "$IFACE" | grep -oP 'inet \K[\d.]+')
if [ -z "$all_configured_ips_on_iface" ]; then
    print_yellow "No IPv4 addresses found configured on $IFACE using 'ip addr show'."
fi

# Create a list of IPs to offer for promotion, excluding burned ones
available_ips_for_promotion=""
for ip_addr in $all_configured_ips_on_iface; do
    is_burned=false
    for burned_ip in $burned_ips_comment; do
        if [[ "$ip_addr" == "$burned_ip" ]]; then
            is_burned=true
            break
        fi
    done
    if ! $is_burned; then
        available_ips_for_promotion="${available_ips_for_promotion}${ip_addr}\n"
    fi
done
available_ips_for_promotion=$(echo -e "${available_ips_for_promotion}" | sed '/^$/d' | sort -uV) # Sort IPs

echo ""
print_blue "IPs currently configured on $IFACE (excluding known 'burned' IPs):"
if [ -n "$available_ips_for_promotion" ]; then
    echo -e "${available_ips_for_promotion}"
else
    print_yellow "No non-burned IPs found on $IFACE to select for promotion."
    print_yellow "This script expects $IFACE to have existing IP aliases."
    exit 1
fi

if [ -n "$burned_ips_comment" ]; then
    print_red "Previously 'burned' IPs (will not be offered for promotion):"
    echo -e "${red}${burned_ips_comment}${clear}"
fi
echo ""

# --- User Input for New Primary IP ---
new_primary_ip=""
while true; do
    read -p "Enter the IP address from the list above to make the new primary for $IFACE: " new_primary_ip
    if [[ "$new_primary_ip" == "$currentIP" ]]; then
        print_yellow "The selected IP ($new_primary_ip) is already the primary IP. No change needed if this is intended."
        print_yellow "If you wish to re-affirm it and clean up aliases, proceed. Otherwise, choose a different IP or Ctrl+C to exit."
        # Allow proceeding if user confirms they want to re-select current primary (e.g. to clean up file)
        break 
    elif echo -e "${available_ips_for_promotion}" | grep -qxF "$new_primary_ip"; then
        break # Valid IP selected from the list
    else
        print_red "Invalid selection. Please enter an IP address exactly as listed above (excluding burned IPs)."
    fi
done

new_primary_last_Oct=$(echo "$new_primary_ip" | awk -F"." '{print $4}')

# --- Generate Temporary Interface Configuration File ---
TMP_INTERFACE_FILE="/tmp/NewIP_$$.tmp"

print_yellow "Generating new configuration for $IFACE..."
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
#iface $IFACE inet dhcp # DHCP is commented out
iface $IFACE inet static
        address $new_primary_ip/24
        gateway $gateway
EOF

# Add existing aliases from /etc/network/interfaces, EXCLUDING the one being promoted
# And also excluding the old primary IP (currentIP) if it was an alias (shouldn't be, but good to be safe)
# This part is tricky: we need to parse /etc/network/interfaces for $IFACE:* stanzas
print_yellow "Processing existing aliases from /etc/network/interfaces for $IFACE..."
awk -v iface="$IFACE" -v new_ip="$new_primary_ip" -v old_primary="$currentIP" '
    BEGIN { record=0; current_alias_ip="" }
    # Match "auto iface:alias_num" or "iface iface:alias_num inet static"
    $1 == "auto" && $2 ~ "^" iface ":" { record=1; current_alias_ip=""; print; next }
    $1 == "iface" && $2 ~ "^" iface ":" && $3 == "inet" && $4 == "static" { record=1; current_alias_ip=""; print; next }
    
    # Inside an alias block, capture the address
    record && $1 == "address" {
        current_alias_ip=$2; # Capture IP with /mask
        sub(/\/.*/, "", current_alias_ip); # Remove /mask to get just IP
    }

    # If we are in a recording block (an alias definition for $IFACE)
    record {
        # Print the line unless the IP of this alias is the one being promoted OR it is the old primary IP
        if (current_alias_ip != "" && current_alias_ip != new_ip && current_alias_ip != old_primary) {
            print
        } else if (current_alias_ip == "") { 
            # This handles the auto/iface lines if address hasn't been parsed yet for this block
            # Or if an alias block doesn't have an address for some reason (should not happen in valid config)
            # This logic is a bit simplified; assumes valid interface file structure
            print 
        }
    }
    
    # Reset record if we encounter a blank line or a line not starting with space (end of stanza)
    NF == 0 { record=0; current_alias_ip="" }
    !/^[ \t]/ { record=0; current_alias_ip="" }
' /etc/network/interfaces >> "$TMP_INTERFACE_FILE"

# Add the OLD primary IP ($currentIP) as a new alias, if it's different from the new primary
if [[ "$currentIP" != "$new_primary_ip" ]]; then
    print_yellow "Adding old primary IP $currentIP as an alias for $IFACE:$last_Oct_currentIP..."
    echo "" >> "$TMP_INTERFACE_FILE"
    echo "# Former primary IP, now an alias (marked as burned by script logic)" >> "$TMP_INTERFACE_FILE"
    echo "# burned $currentIP" >> "$TMP_INTERFACE_FILE"
    echo "auto $IFACE:$last_Oct_currentIP" >> "$TMP_INTERFACE_FILE"
    echo "iface $IFACE:$last_Oct_currentIP inet static" >> "$TMP_INTERFACE_FILE"
    echo "        address $currentIP/24" >> "$TMP_INTERFACE_FILE"
else
    print_yellow "New primary IP is the same as the old primary IP. No alias created for old primary."
    # If the selected IP was already primary, we still mark it as burned in the new file
    # to signify it was processed by the script, if it wasn't already.
    # However, the "burned" comment is primarily for IPs that are *demoted* to aliases.
    # Let's ensure the "burned" comment for the *new* primary IP is NOT added if it's staying primary.
    # The logic above should handle not re-adding it as an alias.
    # We might want to clean up any "burned <new_primary_ip>" comment if it exists.
    sed -i "/^# burned $new_primary_ip/d" "$TMP_INTERFACE_FILE"
fi

# Clean up empty lines that might result from sed or awk processing
sed -i '/^$/N;/^\n$/D' "$TMP_INTERFACE_FILE" # Removes consecutive blank lines
sed -i '/^$/d' "$TMP_INTERFACE_FILE" # Removes any remaining single blank lines

# --- Display Proposed Changes and Confirmation ---
echo ""
print_blue "The following configuration will be written to /etc/network/interfaces:"
echo ""
cat "$TMP_INTERFACE_FILE"
echo ""
yn=""
prompt_text="Does the above look correct (y/N)? You have 15 seconds: "
if read -t 15 -p "$prompt_text" yn_temp < /dev/tty; then
    yn="$yn_temp"
else
    echo # Newline after timeout
    yn="N" # Default to No on timeout
    print_yellow "Timeout reached. Assuming No."
fi
echo ""

# --- Apply Changes or Cancel ---
case $yn in
    [yY] | [yY][eE][sS] )
        print_green "Proceeding with changes..."
        
        time_stamp=$(date +"%Y%m%d_%H%M%S")
        bkpath="/home/$userid/interfaces_backups" # Standardized backup location
        
        print_yellow "Backing up current /etc/network/interfaces to $bkpath/interfaces_as_of_$time_stamp"
        sleep 1
        
        if ! test -d "$bkpath"; then
            mkdir -p "$bkpath"
            if [ $? -ne 0 ]; then
                print_red "Error: Could not create backup directory $bkpath."
                rm "$TMP_INTERFACE_FILE"
                exit 1
            fi
            print_green "Backup directory created: $bkpath"
        fi
        
        if cp /etc/network/interfaces "$bkpath/interfaces_as_of_$time_stamp"; then
            print_green "Backup successful."
        else
            print_red "Error: Failed to backup /etc/network/interfaces. Aborting."
            rm "$TMP_INTERFACE_FILE"
            exit 1
        fi
        
        print_yellow "Updating /etc/network/interfaces..."
        if sudo cp "$TMP_INTERFACE_FILE" /etc/network/interfaces; then
            print_green "Successfully updated /etc/network/interfaces."
            
            # --- Network Restart Section (Kali Linux Optimized) ---
            print_yellow "Attempting to apply network changes for $IFACE on Kali Linux..."
            if sudo systemctl restart networking.service; then
                print_green "Successfully restarted networking.service."
            else
                print_red "Command 'sudo systemctl restart networking.service' failed."
                print_yellow "Attempting fallback: sudo ifdown $IFACE && sudo ifup $IFACE"
                if sudo ifdown "$IFACE" && sudo ifup "$IFACE"; then
                    print_green "Successfully reconfigured $IFACE using ifdown/ifup."
                else
                    print_red "Both 'systemctl restart networking.service' and 'ifdown/ifup $IFACE' failed."
                    print_red "The new IP configuration might not be active."
                    print_yellow "Troubleshooting steps for Kali Linux:"
                    print_yellow "1. Verify syntax in /etc/network/interfaces."
                    print_yellow "2. Check status: sudo systemctl status networking.service"
                    print_yellow "3. Check logs: journalctl -u networking.service -n 50 --no-pager"
                    print_yellow "4. Check NetworkManager: sudo systemctl status NetworkManager.service"
                fi
            fi
            # --- End of Network Restart Section ---
            
            echo ""
            print_blue "Final IP configuration status:"
            ip -br a
        else
            print_red "Error: Failed to write to /etc/network/interfaces."
        fi
        
        rm "$TMP_INTERFACE_FILE"
        print_green "[+] Done!"
        ;;
    * )
        print_yellow "No action taken. Configuration was not applied."
        rm "$TMP_INTERFACE_FILE"
        exit 0
        ;;
esac

exit 0
