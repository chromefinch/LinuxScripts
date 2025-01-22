#!/bin/bash
# written by deepseek llm, edited by me
# Get output directory from user
read -p "Enter the output directory (e.g., ./results): " OUTPUT_DIR
# If no input is given, default to './results'
OUTPUT_DIR=${OUTPUT_DIR:-"./results"}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get input file name from user
read -p "Enter the name of the IP list file (e.g., ips.txt): " ips_file

# Check if the file exists
if [ ! -f "$ips_file" ]; then
    echo "Error: File '$ips_file' not found."
    exit 1
fi

# Read each IP address from the specified file
while IFS= read -r ip; do
    echo "Processing $ip..."
    
    # Download using wget with mirror mode, timeout of 10 seconds, and suppress errors
    wget -m --timeout=10 ftp://anonymous@$ip:21 -P "$OUTPUT_DIR" 2> /dev/null
    
    # Check if the download was successful
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded from $ip."
    else
        echo "Failed to download from $ip."
    fi
    
    # Optional delay between requests
    sleep 1
done < "$ips_file"
