#!/bin/bash

# This script automates the configuration of unattended-upgrades
# on Ubuntu servers to perform weekly updates and reboots.

# Define the desired update schedule
# Day of the week (Mon, Tue, Wed, Thu, Fri, Sat, Sun) and time (HH:MM)
UPDATE_DAY="Mon"
UPDATE_TIME_UPDATE="03:00" # Time for apt update
UPDATE_TIME_UPGRADE="03:15" # Time for unattended-upgrade (after update)

# --- Step 1: Install unattended-upgrades if not already installed ---
echo "Checking for and installing unattended-upgrades..."
if ! dpkg -s unattended-upgrades >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y unattended-upgrades
    echo "unattended-upgrades installed."
else
    echo "unattended-upgrades is already installed."
fi

# --- Step 2: Configure unattended-upgrades settings ---
echo "Configuring /etc/apt/apt.conf.d/50unattended-upgrades..."

# Backup the original file
sudo cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bak.$(date +%Y%m%d_%H%M%S)

# Use sed to modify the file. This is a bit fragile if the file format changes significantly
# Uncomment the line to include regular updates (not just security)
# Use a more robust sed command that handles potential variations in spacing
sudo sed -i '/^ *\/\/ *"*\${distro_id}:\${distro_codename}-updates"*;/{s/\/\/ *//}' /etc/apt/apt.conf.d/50unattended-upgrades

# Uncomment and set automatic reboot if required
# Ensure the line exists before attempting to uncomment/modify
if grep -q "//Unattended-Upgrade::Automatic-Reboot " /etc/apt/apt.conf.d/50unattended-upgrades; then
    sudo sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot "false";/Unattended-Upgrade::Automatic-Reboot "true";/' /etc/apt/apt.conf.d/50unattended-upgrades
    sudo sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot "true";/Unattended-Upgrade::Automatic-Reboot "true";/' /etc/apt/apt.conf.d/50unattended-upgrades # Handle if it was already true
fi

# Uncomment and set the automatic reboot time
# Ensure the line exists before attempting to uncomment/modify
if grep -q "//Unattended-Upgrade::Automatic-Reboot-Time " /etc/apt/apt.conf.d/50unattended-upgrades; then
     sudo sed -i "s/\/\/Unattended-Upgrade::Automatic-Reboot-Time \".*\";/Unattended-Upgrade::Automatic-Reboot-Time \"${UPDATE_TIME_UPGRADE}\";/" /etc/apt/apt.conf.d/50unattended-upgrades
fi

# Example: Configure email notifications (uncomment and set your email)
# if grep -q "//Unattended-Upgrade::Mail " /etc/apt/apt.conf.d/50unattended-upgrades; then
#     sudo sed -i 's/\/\/Unattended-Upgrade::Mail "";/Unattended-Upgrade::Mail "your_email@example.com";/' /etc/apt/apt.conf.d/50unattended-upgrades
# fi

echo "Finished configuring 50unattended-upgrades."

# --- Step 3: Configure periodic update frequency (weekly) ---
echo "Configuring /etc/apt/apt.conf.d/20auto-upgrades for weekly runs..."

# Run dpkg-reconfigure to create/update 20auto-upgrades with defaults
# This is often interactive, but the -plow priority might make it non-interactive
# If it prompts, select 'Yes' for automatic updates.
echo "Running dpkg-reconfigure unattended-upgrades (may prompt)..."
# Use a non-interactive approach for dpkg-reconfigure
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# Now, modify the periodic settings to weekly
sudo cp /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades.bak.$(date +%Y%m%d_%H%M%S)

# Set periodic update list and unattended upgrade to run weekly (every 7 days)
sudo sed -i 's/APT::Periodic::Update-Package-Lists "[0-9]*";/APT::Periodic::Update-Package-Lists "7";/' /etc/apt/apt.conf.d/20auto-upgrades
sudo sed -i 's/APT::Periodic::Unattended-Upgrade "[0-9]*";/APT::Periodic::Unattended-Upgrade "7";/' /etc/apt/apt.conf.d/20auto-upgrades
sudo sed -i 's/APT::Periodic::AutocleanInterval "[0-9]*";/APT::Periodic::AutocleanInterval "7";/' /etc/apt/apt.conf.d/20auto-upgrades

echo "Finished configuring 20auto-upgrades for weekly runs."

# --- Step 4: Create systemd timer overrides for specific weekly schedule ---
echo "Creating systemd timer overrides for weekly schedule (${UPDATE_DAY} at ${UPDATE_TIME_UPDATE} and ${UPDATE_TIME_UPGRADE})..."

# Create directory for apt-daily.timer override
sudo mkdir -p /etc/systemd/system/apt-daily.timer.d/

# Create override file for apt-daily.timer (for apt update)
echo "[Timer]
OnCalendar=${UPDATE_DAY} *-*-* ${UPDATE_TIME_UPDATE}:00
RandomizedDelaySec=0
Persistent=true" | sudo tee /etc/systemd/system/apt-daily.timer.d/override.conf > /dev/null

# Create directory for apt-daily-upgrade.timer override
sudo mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d/

# Create override file for apt-daily-upgrade.timer (for unattended-upgrade)
echo "[Timer]
OnCalendar=${UPDATE_DAY} *-*-* ${UPDATE_TIME_UPGRADE}:00
RandomizedDelaySec=0
Persistent=true" | sudo tee /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf > /dev/null

echo "Finished creating systemd timer overrides."

# --- Step 5: Reload and restart systemd timers ---
echo "Reloading systemd daemon and restarting timers..."
sudo systemctl daemon-reload
sudo systemctl restart apt-daily.timer apt-daily-upgrade.timer

echo "Verifying timer status:"
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer

echo "Script finished. Unattended weekly updates should now be configured."
echo "Check logs in /var/log/unattended-upgrades/ for results after the scheduled time."
