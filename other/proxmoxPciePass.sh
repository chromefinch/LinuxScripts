#!/bin/bash

# ------------------------------------------------------------------------------
# Proxmox IOMMU & Nvidia VFIO Helper Script
# ------------------------------------------------------------------------------
# This script detects CPU architecture and Bootloader type, enables IOMMU,
# loads VFIO modules, and blacklists host Nvidia drivers.
# ------------------------------------------------------------------------------

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}### Proxmox IOMMU & Nvidia VFIO Setup Script ###${NC}"

# Helper function to prompt for confirmation (y/n)
prompt_yes_no() {
    local prompt_text="$1"
    while true; do
        read -r -p "$prompt_text (y/n): " response
        case "$response" in
            [Yy]* ) return 0;; # Success (Yes)
            [Nn]* ) return 1;; # Failure (No)
            * ) echo "Please answer y or n.";;
        esac
    done
}


# --- Configuration Variables ---
# Set this to "true" to enable the ACS override patch.
# RECOMMENDED for consumer motherboards to separate IOMMU groups.
ENABLE_ACS_OVERRIDE="true"
# -------------------------------

# 1. Check for Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root.${NC}"
   exit 1
fi

# 2. Detect CPU Type
echo -e "${YELLOW}Detecting CPU architecture...${NC}"
CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
IOMMU_PARAM=""
KERNEL_PARAMS="iommu=pt" # Always recommended

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    echo -e " - Intel CPU detected. Adding 'intel_iommu=on'."
    IOMMU_PARAM="intel_iommu=on"
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    echo -e " - AMD CPU detected. Adding 'amd_iommu=on'."
    IOMMU_PARAM="amd_iommu=on"
else
    echo -e "${RED}Error: Unknown CPU vendor: $CPU_VENDOR${NC}"
    exit 1
fi

KERNEL_PARAMS="${IOMMU_PARAM} ${KERNEL_PARAMS}"

if [[ "$ENABLE_ACS_OVERRIDE" == "true" ]]; then
    echo -e " - ACS Override is ENABLED. Adding 'pcie_acs_override=downstream'."
    KERNEL_PARAMS="${KERNEL_PARAMS} pcie_acs_override=downstream"
else
    echo -e " - ACS Override is DISABLED. Edit the script to enable it if needed."
fi

# 3. Detect Bootloader (GRUB vs systemd-boot/ZFS-boot-tool)
echo -e "${YELLOW}Detecting Bootloader...${NC}"

BOOTLOADER_TYPE=""

if [ -f /etc/kernel/cmdline ]; then
    if command -v proxmox-boot-tool &> /dev/null && proxmox-boot-tool status | grep -q "configured"; then
        BOOTLOADER_TYPE="systemd-boot"
        echo -e " - Systemd-boot / Proxmox Boot Tool detected (common for ZFS/UEFI)."
    fi
fi

if [[ -z "$BOOTLOADER_TYPE" ]]; then
    if [ -f /etc/default/grub ]; then
        BOOTLOADER_TYPE="grub"
        echo -e " - Standard GRUB detected."
    else
        echo -e "${RED}Error: Could not detect a supported bootloader configuration.${NC}"
        exit 1
    fi
fi

# 4. Update Kernel Parameters
echo -e "${YELLOW}Applying Kernel Parameters ($KERNEL_PARAMS)...${NC}"

if [[ "$BOOTLOADER_TYPE" == "systemd-boot" ]]; then
    CMDLINE_FILE="/etc/kernel/cmdline"
    
    # Backup
    cp $CMDLINE_FILE "${CMDLINE_FILE}.bak"
    
    # Read current content
    CURRENT_CMDLINE=$(cat $CMDLINE_FILE)
    
    # Check if params already exist to avoid duplicates
    if [[ "$CURRENT_CMDLINE" == *"$IOMMU_PARAM"* ]]; then
        echo -e " - Parameters already present in $CMDLINE_FILE. Skipping append."
    else
        # Append parameters to the single line file
        echo "${CURRENT_CMDLINE} ${KERNEL_PARAMS}" > $CMDLINE_FILE
        echo -e " - Updated $CMDLINE_FILE."
        
        # Refresh boot tool
        echo -e " - Refreshing proxmox-boot-tool..."
        proxmox-boot-tool refresh
    fi

elif [[ "$BOOTLOADER_TYPE" == "grub" ]]; then
    GRUB_FILE="/etc/default/grub"
    
    # Backup
    cp $GRUB_FILE "${GRUB_FILE}.bak"
    
    # Check if IOMMU param exists
    if grep -q "$IOMMU_PARAM" "$GRUB_FILE"; then
        echo -e " - IOMMU parameter already present in $GRUB_FILE. Skipping append."
    else
        # Use sed to append all parameters to GRUB_CMDLINE_LINUX_DEFAULT
        # Matches the line, removes the closing quote, adds params, adds closing quote
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& ${KERNEL_PARAMS}/" $GRUB_FILE
        echo -e " - Updated $GRUB_FILE."
        
        # Update GRUB
        echo -e " - Updating GRUB configuration..."
        update-grub
    fi
fi

# 5. Configure VFIO Modules
echo -e "${YELLOW}Configuring /etc/modules...${NC}"
MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")
MODULES_FILE="/etc/modules"

for mod in "${MODULES[@]}"; do
    if grep -Fxq "$mod" "$MODULES_FILE"; then
        echo -e " - Module $mod already present."
    else
        echo "$mod" >> "$MODULES_FILE"
        echo -e " - Added module $mod."
    fi
done

# 6. Setup Blacklist for Nvidia
echo -e "${YELLOW}Blacklisting Nvidia drivers (to prevent host takeover)...${NC}"
BLACKLIST_FILE="/etc/modprobe.d/blacklist-nvidia-vfio.conf"

cat > $BLACKLIST_FILE <<EOF
# Blacklist common Nvidia drivers so they don't claim the GPU on boot
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
EOF
echo -e " - Created $BLACKLIST_FILE"

# 7. Setup Unsafe Interrupts
echo -e "${YELLOW}Setting VFIO unsafe interrupts (for maximum compatibility)...${NC}"
if prompt_yes_no "Do you want to enable 'allow_unsafe_interrupts=1'? (Recommended for initial setup)"; then
    UNSAFE_CONF="/etc/modprobe.d/iommu_unsafe_interrupts.conf"
    if [ ! -f "$UNSAFE_CONF" ] || ! grep -q "allow_unsafe_interrupts=1" "$UNSAFE_CONF"; then
        echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > "$UNSAFE_CONF"
        echo -e " - Created/Updated $UNSAFE_CONF"
    else
        echo -e " - Unsafe interrupts option already set. No changes made."
    fi
else
    echo -e " - Skipped setting 'allow_unsafe_interrupts=1'."
fi


# 8. Setup KVM Options (Ignore MSRS)
echo -e "${YELLOW}Setting KVM options (ignore_msrs)...${NC}"
KVM_CONF="/etc/modprobe.d/kvm.conf"
if [ ! -f "$KVM_CONF" ] || ! grep -q "ignore_msrs=1" "$KVM_CONF"; then
    echo "options kvm ignore_msrs=1" >> "$KVM_CONF"
    echo -e " - Updated $KVM_CONF"
else
    echo -e " - KVM options already set."
fi

# 9. Automatic VFIO Device Binding for ALL Nvidia Devices
echo -e "${YELLOW}--- STEP 9: AUTOMATIC NVIDIA VFIO BINDING ---${NC}"

# Find all Nvidia devices (Vendor ID 10de) and extract their IDs in the format XXXX:YYYY.
# This fixes the awk error by using grep to specifically find the Vendor:Device ID pattern.
NVIDIA_IDS=$(lspci -nn | grep -i 'NVIDIA Corporation' | grep -oE '[0-9a-f]{4}:[0-9a-f]{4}' | tr '\n' ',' | sed 's/,$//')

if [[ -z "$NVIDIA_IDS" ]]; then
    echo -e "${RED}No Nvidia devices found via lspci. Skipping automatic binding.${NC}"
else
    VFIO_IDS_CONF="/etc/modprobe.d/vfio-ids.conf"
    
    # Write the binding configuration file
    cat > $VFIO_IDS_CONF <<EOF
# Automatically generated by VFIO Setup Script. 
# Binds ALL Nvidia devices (GPU cores, HDMI audio, etc.) to vfio-pci.
options vfio-pci ids=$NVIDIA_IDS disable_vga=1
EOF
    echo -e "${GREEN}Successfully created $VFIO_IDS_CONF.${NC}"
    echo -e " - Bound the following IDs to vfio-pci: ${NVIDIA_IDS}"
    echo -e " - Note: 'disable_vga=1' is added to prevent conflicts."
fi

# 10. Final Update Initramfs
echo -e "${YELLOW}Updating Initramfs...${NC}"
update-initramfs -u -k all

echo -e "${GREEN}-----------------------------------------------------"
echo -e "Configuration Complete!"
echo -e "1. All Nvidia devices found have been automatically bound to vfio-pci."
echo -e "2. REBOOT the server for all changes to take effect."
echo -e "3. After reboot, verify IOMMU is enabled: dmesg | grep -e DMAR -e IOMMU -e AMD-Vi"
echo -e "4. Verify devices are using vfio-pci: lspci -nnk | grep -i vfio"
echo -e "-----------------------------------------------------${NC}"
