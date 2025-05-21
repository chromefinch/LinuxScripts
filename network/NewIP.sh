#!/usr/bin/env bash
# Script to change the primary IP address on an interface using nmcli

# --- Configuration & Setup ---
# Ascii art header (using the one from your NewIP script)
red='\033[0;31m'
clear_color='\033[0m' # Renamed to avoid conflict with clear command
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
echo -e "${clear_color}"


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
echo "                                     NewIP (nmcli Edition) - Primary IP Changer"
print_purple "This script uses NetworkManager (nmcli) to change the primary IP."
print_purple "It assumes a /24 address space for all IPs on the connection."
echo ""

# --- Configuration ---
BURNED_IPS_FILE=~/.nmcli_burned_ips.txt
touch "$BURNED_IPS_FILE" # Ensure the file exists

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
    exit 1
fi
print_green "Detected network interface: $IFACE"

userid=$SUDO_USER
if [ -z "$userid" ]; then
    userid=$(whoami)
fi

# --- Get NetworkManager Connection ID for the Interface ---
print_blue "Attempting to find NetworkManager connection profile for $IFACE..."
CON_ID=""
ACTIVE_CON_ID=$(nmcli -t -f UUID,DEVICE connection show --active | grep -E "(^|:)${IFACE}($|:)" | head -n1 | cut -d':' -f1)

if [ -n "$ACTIVE_CON_ID" ]; then
    CON_ID="$ACTIVE_CON_ID"
else
    CONFIGURED_CON_ID=$(nmcli -t -f UUID,DEVICE connection show | grep -E "(^|:)${IFACE}($|:)" | head -n1 | cut -d':' -f1)
    if [ -n "$CONFIGURED_CON_ID" ]; then
        CON_ID="$CONFIGURED_CON_ID"
        print_yellow "Using configured (but possibly inactive) connection for $IFACE."
    fi
fi

if [ -z "$CON_ID" ]; then
    print_red "No NetworkManager connection profile found for interface $IFACE."
    exit 1
else
    CON_NAME=$(nmcli -t -f NAME,UUID connection show | grep "$CON_ID" | head -n1 | cut -d':' -f1)
    print_green "Using NetworkManager connection: '$CON_NAME' (UUID: $CON_ID) for interface $IFACE"
fi

# --- Get Current Network Configuration from NetworkManager ---
print_blue "Fetching current network configuration for '$CON_NAME'..."
current_nm_config=$(nmcli -t -f ipv4.method,ipv4.addresses,ipv4.gateway connection show "$CON_ID")
current_ipv4_method=$(echo "$current_nm_config" | grep -oP 'ipv4.method:\K[^:]+' | head -n1)
current_ip_list_str=$(echo "$current_nm_config" | grep -oP 'ipv4.addresses:\K[^:]+' | head -n1)
current_gateway=$(echo "$current_nm_config" | grep -oP 'ipv4.gateway:\K[^:]+' | head -n1)

if [[ "$current_ipv4_method" != "manual" ]]; then
    print_yellow "Warning: IPv4 method for '$CON_NAME' is currently '$current_ipv4_method', not 'manual'."
    print_yellow "This script will change it to 'manual'."
fi

if [ -z "$current_ip_list_str" ]; then
    print_red "No IP addresses currently configured on connection '$CON_NAME'."
    print_yellow "This script is intended to change the primary among existing IPs."
    exit 1
fi

# Convert comma-separated IP list to an array (Bash 4+) or newline-separated for processing
IFS=',' read -r -a current_ip_array <<< "$current_ip_list_str"

# Identify current primary IP (first in the list from nmcli)
# We need to strip the prefix for comparison and display
current_primary_ip_with_prefix="${current_ip_array[0]}"
current_primary_ip=$(echo "$current_primary_ip_with_prefix" | cut -d'/' -f1)

print_green "Current primary IP on '$CON_NAME': $current_primary_ip (full: $current_primary_ip_with_prefix)"
if [ -n "$current_gateway" ]; then
    print_green "Current gateway: $current_gateway"
else
    print_yellow "No gateway currently configured on '$CON_NAME'."
fi

# --- Display Available and Burned IPs ---
print_yellow "Loading burned IPs from $BURNED_IPS_FILE..."
mapfile -t burned_ips_array < "$BURNED_IPS_FILE" # Read burned IPs into an array

available_ips_for_promotion=()
all_configured_ips_display=()

print_blue "Currently configured IPs on '$CON_NAME':"
for ip_with_prefix in "${current_ip_array[@]}"; do
    ip_addr_only=$(echo "$ip_with_prefix" | cut -d'/' -f1)
    all_configured_ips_display+=("$ip_addr_only ($ip_with_prefix)")

    is_burned=false
    for burned_ip in "${burned_ips_array[@]}"; do
        if [[ "$ip_addr_only" == "$burned_ip" ]]; then
            is_burned=true
            break
        fi
    done

    if ! $is_burned; then
        available_ips_for_promotion+=("$ip_with_prefix") # Store with prefix for nmcli
    fi
done

# Display all configured IPs
for display_ip in "${all_configured_ips_display[@]}"; do
    echo "  - $display_ip"
done


if [ ${#available_ips_for_promotion[@]} -eq 0 ]; then
    print_red "No non-burned IPs available to be promoted to primary."
    if [ ${#current_ip_array[@]} -gt 0 ]; then
        print_yellow "All currently configured IPs are marked as burned in $BURNED_IPS_FILE."
        print_yellow "Consider editing $BURNED_IPS_FILE to unburn an IP if you wish to promote one."
    fi
    exit 1
fi

echo ""
print_blue "IPs available for promotion to primary (excluding burned IPs):"
for i in "${!available_ips_for_promotion[@]}"; do
    printf "  %d) %s\n" "$((i+1))" "${available_ips_for_promotion[$i]}"
done

if [ ${#burned_ips_array[@]} -gt 0 ]; then
    print_red "Previously 'burned' IPs (will not be offered for promotion as primary):"
    for burned_ip in "${burned_ips_array[@]}"; do
        echo -e "  - ${red}${burned_ip}${clear_color}"
    done
fi
echo ""

# --- User Input for New Primary IP ---
new_primary_ip_with_prefix=""
while true; do
    read -p "Enter the number of the IP to make the new primary (or 'q' to quit): " selection
    if [[ "$selection" == "q" ]]; then
        print_yellow "Operation cancelled by user."
        exit 0
    fi
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#available_ips_for_promotion[@]} ]; then
        new_primary_ip_with_prefix="${available_ips_for_promotion[$((selection-1))]}"
        break
    else
        print_red "Invalid selection. Please enter a number from the list."
    fi
done

new_primary_ip_only=$(echo "$new_primary_ip_with_prefix" | cut -d'/' -f1)

if [[ "$new_primary_ip_only" == "$current_primary_ip" ]]; then
    print_yellow "The selected IP ($new_primary_ip_only) is already the primary IP."
    print_yellow "No changes will be made to the IP order, but the connection will be reapplied."
    # No need to burn it again if it's already primary
else
    print_green "Selected new primary IP: $new_primary_ip_only ($new_primary_ip_with_prefix)"
fi


# --- Reconstruct IP List for NetworkManager ---
# New primary goes first, then other non-promoted IPs, then the old primary (if different and not the new primary)
# This ensures the old primary is still configured but no longer first.
final_ip_list_array=()
final_ip_list_array+=("$new_primary_ip_with_prefix") # Add new primary first

# Add other existing IPs, excluding the new primary and the old primary (it will be added last if needed)
for ip_wp in "${current_ip_array[@]}"; do
    if [[ "$ip_wp" != "$new_primary_ip_with_prefix" && "$ip_wp" != "$current_primary_ip_with_prefix" ]]; then
        final_ip_list_array+=("$ip_wp")
    fi
done

# Add the old primary IP last if it's different from the new primary and not already included
if [[ "$current_primary_ip_with_prefix" != "$new_primary_ip_with_prefix" ]]; then
    # Check if old primary is already in the list (e.g. if it was the only other IP)
    already_exists=false
    for item in "${final_ip_list_array[@]}"; do
        if [[ "$item" == "$current_primary_ip_with_prefix" ]]; then
            already_exists=true
            break
        fi
    done
    if ! $already_exists; then
         final_ip_list_array+=("$current_primary_ip_with_prefix")
    fi
fi


# Convert array to comma-separated string for nmcli
final_comma_separated_ips=$(IFS=,; echo "${final_ip_list_array[*]}")


# --- Display Proposed Changes and Confirmation ---
echo ""
print_purple "--- Proposed NetworkManager Configuration ---"
print_blue "Connection Profile: '$CON_NAME' (UUID: $CON_ID)"
print_blue "IPv4 Method:       manual (will be enforced)"
print_blue "IP Addresses (new order): $final_comma_separated_ips"
if [ -n "$current_gateway" ]; then
    print_blue "Gateway (preserved): $current_gateway"
else
    print_yellow "Gateway: (Not Set/Preserved as Not Set)"
fi
if [[ "$new_primary_ip_only" != "$current_primary_ip" ]]; then
    print_yellow "Old primary IP '$current_primary_ip' will be added to $BURNED_IPS_FILE."
fi
echo "----------------------------------------"
echo ""

read -t 20 -p "Does the above look correct (y/N)? You have 20 seconds: " yn < /dev/tty
echo ""

# --- Apply Changes or Cancel ---
case $yn in
    [yY] | [yY][eE][sS] )
        print_green "Proceeding with NetworkManager configuration..."

        # Mark old primary as burned if it changed
        if [[ "$new_primary_ip_only" != "$current_primary_ip" ]]; then
            # Avoid adding duplicates to burned file
            if ! grep -qxF "$current_primary_ip" "$BURNED_IPS_FILE"; then
                echo "$current_primary_ip" >> "$BURNED_IPS_FILE"
                print_yellow "Old primary IP '$current_primary_ip' marked as burned in $BURNED_IPS_FILE."
            else
                print_yellow "Old primary IP '$current_primary_ip' was already in $BURNED_IPS_FILE."
            fi
        fi
        
        gateway_arg=""
        if [ -n "$current_gateway" ]; then
            gateway_arg="ipv4.gateway $current_gateway"
        else
            gateway_arg="ipv4.gateway ''" # Explicitly clear if was not set
        fi

        # --- DEBUGGING LINES ---
        print_yellow "-----------------------------------------------------"
        print_yellow "DEBUG: About to modify connection."
        print_yellow "DEBUG: CON_ID: [$CON_ID]"
        print_yellow "DEBUG: final_comma_separated_ips: [$final_comma_separated_ips]"
        print_yellow "DEBUG: gateway_arg: [$gateway_arg]"
        print_yellow "DEBUG: Full nmcli modify command (before sudo) would be:"
        print_yellow "nmcli connection modify \"$CON_ID\" ipv4.method manual ipv4.addresses \"$final_comma_separated_ips\" $gateway_arg"
        print_yellow "-----------------------------------------------------"
        # --- END OF DEBUGGING LINES ---

        if sudo nmcli connection modify "$CON_ID" ipv4.method manual ipv4.addresses "$final_comma_separated_ips" $gateway_arg; then
            print_green "Connection profile '$CON_NAME' modified successfully."
            
            print_yellow "Attempting to reapply configuration to $IFACE..."
            if sudo nmcli device reapply "$IFACE"; then
                print_green "Configuration reapplied to $IFACE successfully."
            elif sudo nmcli connection up "$CON_ID" ifname "$IFACE"; then # Fallback
                print_green "Connection '$CON_NAME' activated on $IFACE successfully."
            else
                print_red "Failed to reapply or activate connection on $IFACE."
                print_yellow "Check 'nmcli device status', 'nmcli connection show \"$CON_NAME\"'."
            fi
        else
            print_red "Failed to modify NetworkManager connection profile '$CON_NAME'."
            print_yellow "Check permissions, NetworkManager status, and nmcli error messages."
        fi

        echo ""
        print_blue "Final IP configuration (from 'ip -c addr show dev $IFACE'):"
        ip -c addr show dev "$IFACE"
        echo ""
        print_blue "NetworkManager connection details for '$CON_NAME' (ipv4.addresses):"
        nmcli -t -f ipv4.addresses connection show "$CON_ID"


        print_green "[+] Done!"
        ;;
    * )
        print_yellow "No action taken. NetworkManager configuration not changed."
        exit 0
        ;;
esac

exit 0
