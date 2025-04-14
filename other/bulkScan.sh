#!/usr/bin/env bash
pwd
ls -1

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

if [[ $EUID -ne 0 ]]; then
    print_red "This script must be run as root"
        exit 1
fi

# --- User Input ---
read -p "Enter a unique scan title (e.g., ProjectX_Q1_Scan): " SCAN_TITLE
read -p "Enter the path to the host list file: " HOST_LIST_FILE

# --- Input Validation ---
if [[ -z "$SCAN_TITLE" ]]; then
  print_red "Error: Scan title cannot be empty."
  exit 1
fi
if [[ ! -f "$HOST_LIST_FILE" ]]; then
  print_red "Error: Host list file '$HOST_LIST_FILE' not found."
  exit 1
fi

print_yellow "--- Starting Scan: ${SCAN_TITLE} ---"
print_yellow "--- Using Host List: ${HOST_LIST_FILE} ---"

# --- Phase 1: Discovery (SYN Scan, Top 1000, No Ping) ---
print_blue "[+] Phase 1: Discovery Scan (Top 1000 Ports, No Ping)"
nmap -sS -T4 --max-retries 1 --max-rtt-timeout 300ms --host-timeout 5m -Pn -n \
     -iL "${HOST_LIST_FILE}" \
     --top-ports 1000 \
     -oA "${SCAN_TITLE}_phase1_Top1kPorts"

# --- Phase 2: Ping Sweep (Optional - Run against original list) ---
# Note: Phase 1 already performs discovery via SYN packets.
# This phase performs an ICMP/ARP based discovery on the original list.
print_blue "[+] Phase 2: Ping Sweep on original list"
nmap -sn -T4 --max-retries 1 --max-rtt-timeout 300ms --host-timeout 5m -n \
     -iL "${HOST_LIST_FILE}" \
     -oA "${SCAN_TITLE}_phase2_PingSweep"

# --- Extract Live Hosts (Primarily from Phase 1 SYN Scan) ---
print_blue "[+] Extracting Live Hosts found in Phases 1 & 2"
# Using .nmap output; consider using .gnmap 'Status: Up' for potentially more reliable parsing
grep "Host: " "${SCAN_TITLE}_phase1_Top1kPorts.gnmap" | awk '{print $2}' > "${SCAN_TITLE}_live_hosts.txt"
# Optional: Add hosts found *only* by Phase 2 ping sweep if needed
grep "Host: " "${SCAN_TITLE}_phase2_PingSweep.gnmap" | awk '{print $2}' >> "${SCAN_TITLE}_live_hosts.txt"
sort -u "${SCAN_TITLE}_live_hosts.txt" -o "${SCAN_TITLE}_live_hosts.txt" # Keep unique if merging

if [[ ! -s "${SCAN_TITLE}_live_hosts.txt" ]]; then
    print_red "[!] Warning: No live hosts found in Phase 1 based on grep pattern."
    # Consider exiting or modifying logic if no hosts are found
fi
print_green "[+] Live hosts saved to ${SCAN_TITLE}_live_hosts.txt"

# --- Phase 3: Discover all ports ---
print_blue "[+] Phase 3: Scan All Ports on Live Hosts"
if [[ -s "${SCAN_TITLE}_live_hosts.txt" ]]; then
    nmap -sS -T4 --max-retries 1 --max-rtt-timeout 300ms --host-timeout 5m -Pn -n \
         -iL "${SCAN_TITLE}_live_hosts.txt" \
         -p- \
         -oA "${SCAN_TITLE}_phase3_Top1k_Live"
else
    print_red "[!] Skipping Phase 3: No live hosts found in ${SCAN_TITLE}_live_hosts.txt."
fi

# --- Extract Open Ports (From Phase 1 Scan Results) ---
print_blue "[+] Extracting Open Ports discovered in Phase 3"
# grep "^[0-9]\+\/.*state open" "${SCAN_TITLE}_phase3_Top1k_Live.gnmap" | awk -F '/' '{print $1}' | sort -nu > "${SCAN_TITLE}_open_ports.txt"
# Alternative using .gnmap (often more reliable):
grep -oP '\d+/open' "${SCAN_TITLE}_phase1_Top1kPorts.gnmap" | cut -d '/' -f 1 | sort -nu > "${SCAN_TITLE}_open_ports.txt"

if [[ ! -s "${SCAN_TITLE}_open_ports.txt" ]]; then
    print_red "[!] Warning: No open ports found in Phase 1 scan results."
fi
print_green "[+] Open ports saved to ${SCAN_TITLE}_open_ports.txt"

# --- Phase 4: Deep Scan (Version/Script/OS) on Live Hosts & Found Ports ---
print_blue "[+] Phase 4: Deep Scan on Live Hosts and Found Ports"
if [[ -s "${SCAN_TITLE}_live_hosts.txt" && -s "${SCAN_TITLE}_open_ports.txt" ]]; then
    # Format ports for nmap -p option (comma-separated, no whitespace)
    PORTS=$(paste -sd, "${SCAN_TITLE}_open_ports.txt")

    if [[ -n "$PORTS" ]]; then
        print_blue "[*] Scanning ports: ${PORTS} on hosts in ${SCAN_TITLE}_live_hosts.txt"
        nmap -A -T4 --max-retries 1 --max-rtt-timeout 300ms --host-timeout 5m -Pn \
             -iL "${SCAN_TITLE}_live_hosts.txt" \
             -p "${PORTS}" \
             -oA "${SCAN_TITLE}_phase4_DeepScan"
    else
        print_red "[!] Skipping Phase 4: Failed to format port list from ${SCAN_TITLE}_open_ports.txt."
    fi
else
    print_red "[!] Skipping Phase 4: Missing live hosts (${SCAN_TITLE}_live_hosts.txt) or open ports (${SCAN_TITLE}_open_ports.txt)."
fi

print_blue "--- Scan ${SCAN_TITLE} Complete ---"
