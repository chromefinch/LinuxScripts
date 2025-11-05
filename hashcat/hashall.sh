#!/bin/bash
exec > >(tee -a hashlogfile.txt) 2>&1

# sudo ./hashall.sh domain.hash lists
# d3ad0ne.rule
# best64.rule
# appendAlphNum2.rule
# rockyou-30000.rule
# sudo hashcat -m 1000 --show domain.hash
# A simple script to iterate through files in a directory and use each filename in a command.
# This script is for educational purposes to demonstrate safe file handling in bash.

# --- Configuration ---
# Set the target directory here. Using "." means the current directory.
# For safety, it's best to use a specific, non-critical path.
hash="$1"
TARGET_DIR="$2"

# --- Main Logic ---

# Check if the target directory exists to prevent errors.
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' not found."
  exit 1
fi

echo "Starting to process files in directory: $TARGET_DIR"
echo "--------------------------------------------------"

# Use a for loop to go through each item in the directory.
# The "*" is a glob that matches all files and directories.
for FILE in "$TARGET_DIR"/*
do
  # Check if the item is actually a file (and not a directory).
  if [ -f "$FILE" ]; then
    # --- This is where you use the file as a variable ---
    # This example command will just print the name of the file.
    # It is a safe, non-destructive operation.
    echo "Processing file: $FILE"
    sudo hashcat -m 1000 $hash $FILE -r Optimised-hashcat-Rule/OneRuleToRuleThemAll.rule -O 
    # Example of another safe command: getting the word count of a file.
    # Un-comment the line below to try it.
    # wc -w "$FILE"
  fi
done

echo "--------------------------------------------------"
echo "Finished processing all files."
