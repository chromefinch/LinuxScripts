#!/usr/bin/python3

import os
import sys
import subprocess
import json # For potentially more complex udevadm output if needed, though properties are simpler

# update sudo nano /etc/udev/rules.d/90-qemu-usb-hotplug.rules
# with
# ACTION=="add|remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", RUN+="/usr/local/bin/qemu-usb-hotplug.py"
# and then run udevadm trigger
# sudo udevadm control --reload-rules
# sudo udevadm trigger

# --- Configuration ---
# VM_DOMAIN_NAME: {
#     "rules": [
#         {"match_devpath_prefix": "/sys/devices/pci0000:00/0000:00:14.0/usbX/X-Y"}, # Match by physical port path
#         {"match_ids": {"ID_VENDOR_ID": "1234", "ID_PRODUCT_ID": "5678"}}     # Match by specific device
#     ]
# }
# Note: DEVPATH usually starts with /sys/devices/... when obtained from udev environment.
# The udevadm monitor output you provided shows /devices/..., ensure your config matches what $DEVPATH provides.
# This script assumes $DEVPATH starts with /sys/devices/...
# If your $DEVPATH from udev is like "/devices/...", you might need to adjust prefixes
# or add "/sys" when calling udevadm info. For this script, we'll assume $DEVPATH is the /sys path.

CONFIG = {
    "kali": {  # Replace with your actual VM domain name
        "rules": [
            # Example: Pass through any device connected to a specific USB port
            # You'll need to identify the correct DEVPATH prefix for your target port.
            # From your udevadm monitor output, a port path could be like:
            # "/sys/devices/pci0000:00/0000:00:14.0/usb3/3-6"
            # Or for a device connected to it: "/sys/devices/pci0000:00/0000:00:14.0/usb3/3-6/3-6.1" (example)
            # So the prefix would be the path to the port itself.
            {"match_devpath_prefix": "/devices/pci0000:00/0000:00:14.0/usb4/4-2"},
#            {"match_devpath_prefix": "/devices/pci0000:00/0000:00:0d.0/usb2/2-1"},
            {"match_devpath_prefix": "/devices/pci0000:00/0000:00:14.0/usb3/3-6"},

            # Example: Pass through a specific keyboard by its vendor/product ID
            # {"match_ids": {"ID_VENDOR_ID": "046d", "ID_PRODUCT_ID": "c31c"}} # Logitech K120 keyboard
        ]
    }
}

DEBUG = True  # Set to False for production
DEBUG_FILE = "/tmp/qemu-usb-hotplug.log" # Ensure this path is writable by the user udev runs the script as (often root)

# --- Helper Functions ---

def log_debug(message):
    """Writes a message to the debug log file and stderr if DEBUG is True."""
    if DEBUG:
        print(f"DEBUG: {message}", file=sys.stderr)
    if DEBUG_FILE:
        try:
            with open(DEBUG_FILE, "a") as f:
                f.write(f"{message}\n")
        except IOError as e:
            if DEBUG: # Avoid log loop if logging itself fails
                print(f"ERROR: Could not write to debug file {DEBUG_FILE}: {e}", file=sys.stderr)

def run_command(command_args):
    """Executes a command and returns its output or raises an exception."""
    log_debug(f"Executing command: {' '.join(command_args)}")
    try:
        process = subprocess.Popen(command_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        if process.returncode != 0:
            log_debug(f"Command failed with code {process.returncode}")
            log_debug(f"Stdout: {stdout.strip()}")
            log_debug(f"Stderr: {stderr.strip()}")
            raise subprocess.CalledProcessError(process.returncode, command_args, output=stdout, stderr=stderr)
        log_debug(f"Command successful. Stdout: {stdout.strip()}")
        return stdout.strip()
    except Exception as e:
        log_debug(f"Exception during command execution: {e}")
        raise

def get_udev_properties(sys_devpath):
    """
    Fetches udev properties for a given sysfs device path.
    DEVPATH from udev environment should be a sysfs path (e.g., /sys/devices/...).
    """
    if not sys_devpath:
        log_debug("Cannot get udev properties: sys_devpath is empty.")
        return {}
    if not sys_devpath.startswith("/sys/"):
        # If DEVPATH from environment is like "/devices/...", prepend "/sys"
        # This depends on how your udev rule populates DEVPATH.
        # Standard $DEVPATH is usually the full sysfs path.
        log_debug(f"DEVPATH '{sys_devpath}' does not start with /sys/. Assuming it's a suffix and prepending /sys.")
        # If your DEVPATH is already /sys/... then this logic might need adjustment
        # For now, let's assume DEVPATH is the full path.
        # If it's /devices/foo, it should be /sys/devices/foo for udevadm
        # The original script used os.getenv("DEVPATH") which gives /devices/...
        # So, we need to ensure it's compatible with `udevadm info -p`
        query_path = f"/sys{sys_devpath}" if sys_devpath.startswith("/devices/") else sys_devpath


    properties = {}
    try:
        # Using -q property is cleaner than parsing -a
        output = run_command(["udevadm", "info", "-q", "property", "-p", query_path])
        for line in output.splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                properties[key] = value
    except subprocess.CalledProcessError:
        log_debug(f"Failed to get udev properties for {query_path}.")
    except Exception as e:
        log_debug(f"An unexpected error occurred while getting udev properties for {query_path}: {e}")
    return properties

def manage_usb_device_virsh(vm_domain, action, busnum, devnum):
    """
    Attaches or detaches a USB device from a VM using virsh.
    action: 'attach-device' or 'detach-device'
    """
    if not all([vm_domain, action, busnum, devnum]):
        log_debug(f"Missing parameters for virsh command: vm={vm_domain}, action={action}, bus={busnum}, dev={devnum}")
        return False

    device_xml = f"""
    <hostdev mode="subsystem" type="usb" managed="yes">
      <source>
        <address bus="{busnum}" device="{devnum}"/>
      </source>
    </hostdev>
    """
    log_debug(f"Generated XML for virsh: {device_xml.strip()}")

    # virsh expects XML via stdin, so we create a temporary file-like object
    # or pass it directly if using a method that supports it.
    # For attach-device/detach-device, it's often easier to pass a file path to the XML.
    # However, piping to stdin is also common.

    virsh_command = ["virsh", action, vm_domain, "/dev/stdin"]

    log_debug(f"Attempting to {action} device bus={busnum},dev={devnum} for VM {vm_domain}")
    try:
        process = subprocess.Popen(virsh_command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate(input=device_xml)

        if process.returncode == 0:
            log_debug(f"Successfully executed: {action} for bus {busnum}, device {devnum} on {vm_domain}.")
            log_debug(f"Virsh stdout: {stdout.strip()}")
            return True
        else:
            log_debug(f"virsh command failed for {action} on {vm_domain} (bus {busnum}, dev {devnum}).")
            log_debug(f"Return code: {process.returncode}")
            log_debug(f"Virsh stdout: {stdout.strip()}")
            log_debug(f"Virsh stderr: {stderr.strip()}")
            # Common error for detach: "Failed to detach device" if not found or already detached.
            # Common error for attach: "Failed to attach device" if already attached or issues with host device.
            if "already attached" in stderr.lower() and action == "attach-device":
                log_debug("Device reported as already attached. No action needed.")
                return True # Treat as success if already in desired state
            if "not found" in stderr.lower() and action == "detach-device":
                log_debug("Device reported as not found for detachment. No action needed.")
                return True # Treat as success if already in desired state

            return False
    except Exception as e:
        log_debug(f"Exception during virsh command: {e}")
        return False

# --- Main Logic ---

def main():
    log_debug("--- QEMU USB Hotplug Script START ---")

    # Get environment variables set by udev
    action = os.environ.get("ACTION")
    devpath = os.environ.get("DEVPATH") # Expected to be like /sys/devices/... or /devices/...
    subsystem = os.environ.get("SUBSYSTEM")
    devtype = os.environ.get("DEVTYPE")
    busnum_str = os.environ.get("BUSNUM")
    devnum_str = os.environ.get("DEVNUM")
    
    # These might be directly available from udev if configured in the rule
    id_vendor_id = os.environ.get("ID_VENDOR_ID")
    id_product_id = os.environ.get("ID_PRODUCT_ID")

    log_debug(f"Received udev event: ACTION={action}, DEVPATH={devpath}, SUBSYSTEM={subsystem}, DEVTYPE={devtype}, BUSNUM={busnum_str}, DEVNUM={devnum_str}, ID_VENDOR_ID={id_vendor_id}, ID_PRODUCT_ID={id_product_id}")

    if not action or not devpath or not subsystem:
        log_debug("Missing critical environment variables (ACTION, DEVPATH, SUBSYSTEM). Exiting.")
        sys.exit(1)

    if subsystem != "usb":
        log_debug(f"Ignoring non-USB subsystem: {subsystem}. Exiting.")
        sys.exit(0)

    # IMPORTANT: Only act on 'usb_device' types to avoid multiple triggers for interfaces of the same device.
    # This is a key change to prevent duplicate attachments.
    if devtype != "usb_device":
        log_debug(f"Ignoring DEVTYPE '{devtype}'. Only processing 'usb_device'. Exiting.")
        sys.exit(0)

    if action not in ["add", "remove"]:
        log_debug(f"Unsupported ACTION: {action}. Exiting.")
        sys.exit(0)

    if not busnum_str or not devnum_str:
        log_debug("BUSNUM or DEVNUM not provided in environment. Cannot proceed. Exiting.")
        # This can happen if the udev event is for a hub that doesn't have them in the same way,
        # but for DEVTYPE=usb_device, they should be present.
        sys.exit(1)
        
    try:
        busnum = int(busnum_str)
        devnum = int(devnum_str)
    except ValueError:
        log_debug(f"Invalid BUSNUM ('{busnum_str}') or DEVNUM ('{devnum_str}'). Exiting.")
        sys.exit(1)

    # Fetch additional properties if not already in environment (e.g. for match_ids)
    # Ensure devpath used for udevadm info is the correct sysfs path
    # The original script's DEVPATH was like /devices/pci...
    # udevadm info -p needs /sys/devices/pci...
    # Let's assume devpath from environment is /sys/devices/...
    # If it's /devices/..., the get_udev_properties function will try to prepend /sys
    
    # If vendor/product IDs are not directly from env, fetch them
    # This is only needed if any rule uses match_ids
    device_properties = {}
    needs_props_for_matching = any(
        "match_ids" in rule
        for vm_config in CONFIG.values()
        for rule in vm_config.get("rules", [])
    )

    if needs_props_for_matching and (not id_vendor_id or not id_product_id):
        log_debug("Fetching device properties for ID matching...")
        # Adjust devpath for udevadm if it's not already a /sys path
        actual_sys_devpath = devpath
        if devpath.startswith("/devices/"):
             actual_sys_devpath = f"/sys{devpath}"
        elif not devpath.startswith("/sys/"):
             log_debug(f"DEVPATH '{devpath}' format is unexpected. Assuming it can be used directly with udevadm if not /devices/ prefix.")
             # This case might need review based on actual udev $DEVPATH format on the system.

        device_properties = get_udev_properties(actual_sys_devpath)
        id_vendor_id = id_vendor_id or device_properties.get("ID_VENDOR_ID")
        id_product_id = id_product_id or device_properties.get("ID_PRODUCT_ID")
        log_debug(f"Properties fetched: ID_VENDOR_ID={id_vendor_id}, ID_PRODUCT_ID={id_product_id}")


    # Determine virsh operation
    virsh_action = "attach-device" if action == "add" else "detach-device"

    # Iterate through configured VMs and their rules
    for vm_domain, vm_config in CONFIG.items():
        for rule in vm_config.get("rules", []):
            matched = False
            if "match_devpath_prefix" in rule:
                prefix = rule["match_devpath_prefix"]
                # Ensure devpath from udev (e.g. /sys/devices/...) is used for comparison
                if devpath.startswith(prefix):
                    log_debug(f"DEVPATH '{devpath}' matches prefix '{prefix}' for VM '{vm_domain}'.")
                    matched = True
            
            if not matched and "match_ids" in rule:
                if id_vendor_id and id_product_id: # Ensure we have IDs to compare
                    rule_vendor = rule["match_ids"].get("ID_VENDOR_ID")
                    rule_product = rule["match_ids"].get("ID_PRODUCT_ID")
                    if id_vendor_id == rule_vendor and id_product_id == rule_product:
                        log_debug(f"Device IDs ({id_vendor_id}:{id_product_id}) match rule for VM '{vm_domain}'.")
                        matched = True
                else:
                    log_debug(f"Skipping ID match for VM '{vm_domain}': device IDs not available (Vendor: {id_vendor_id}, Product: {id_product_id}).")


            if matched:
                log_debug(f"Rule matched for VM '{vm_domain}'. Performing '{virsh_action}'.")
                if manage_usb_device_virsh(vm_domain, virsh_action, busnum, devnum):
                    log_debug(f"Successfully processed {devpath} for {vm_domain}.")
                else:
                    log_debug(f"Failed to process {devpath} for {vm_domain}.")
                # Assuming a device should only be handled by the first matching rule/VM.
                # If a device could be attached to multiple VMs (not typical for passthrough), remove sys.exit.
                sys.exit(0) # Processed, so exit

    log_debug(f"No matching rule found for device {devpath} (IDs: {id_vendor_id}:{id_product_id}). No action taken.")
    log_debug("--- QEMU USB Hotplug Script END ---")
    sys.exit(0)

if __name__ == "__main__":
    # This script is intended to be run by udev, which sets environment variables.
    # For direct testing, you might need to mock these variables.
    # Example for testing:
    # os.environ["ACTION"] = "add"
    # os.environ["DEVPATH"] = "/sys/devices/pci0000:00/0000:00:14.0/usb3/3-3/3-3.1/3-3.1:1.0" # Example, adjust
    # os.environ["SUBSYSTEM"] = "usb"
    # os.environ["DEVTYPE"] = "usb_device" # or usb_interface to test filtering
    # os.environ["BUSNUM"] = "003" # Example
    # os.environ["DEVNUM"] = "007" # Example
    # os.environ["ID_VENDOR_ID"] = "1234"
    # os.environ["ID_PRODUCT_ID"] = "5678"
    try:
        main()
    except Exception as e:
        log_debug(f"Unhandled exception in main: {e}")
        log_debug(traceback.format_exc()) # Requires import traceback
        sys.exit(1)

