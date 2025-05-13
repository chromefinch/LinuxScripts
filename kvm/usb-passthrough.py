#!/usr/bin/python3

import subprocess
import sys
import os
import xml.etree.ElementTree as ET
import re
from typing import Optional, List, Dict

# place in /usr/local/sbin/usb-passthrough.py
# Configuration
CONFIG = {
    "win11-2": {
        "usb_controllers": [
            "/sys/devices/pci0000:00/0000:00:14.0",  # Example: USB controller path
            # Add more USB controller paths as needed for your setup
        ],
    },
}

# Debugging
DEBUG = True
DEBUG_FILE = "/var/log/autousb.log"


def log(message: str) -> None:
    """Logs messages to stderr and optionally to a file."""
    if DEBUG:
        print(message, file=sys.stderr)
    if DEBUG_FILE:
        with open(DEBUG_FILE, "a") as f:
            f.write(message + "\n")


def get_device_info() -> Optional[Dict[str, str]]:
    """
    Retrieves device information from udev environment variables.

    Returns:
        A dictionary containing device information, or None if essential
        variables are missing.  Now focuses on the parent device path.
    """
    devpath = os.getenv("DEVPATH")
    action = os.getenv("ACTION")
    subsystem = os.getenv("SUBSYSTEM")

    if not devpath or not action or not subsystem:
        log(
            f"Missing essential environment variables. DEVPATH={devpath}, ACTION={action}, SUBSYSTEM={subsystem}"
        )
        return None

    return {
        "devpath": devpath,
        "action": action,
        "subsystem": subsystem,
    }



def get_vm_config(device_info: Dict[str, str]) -> Optional[str]:
    """
    Finds the VM configuration based on the USB controller path.

    Returns:
        The name of the VM if a match is found, otherwise None.
    """
    if device_info["subsystem"] != "usb":
        return None

    # Find the parent USB controller device path.  This is crucial.
    parent_path = os.path.dirname(device_info["devpath"])
    if not parent_path:
        log(f"Could not find parent path for {device_info['devpath']}")
        return None

    for vm_name, vm_config in CONFIG.items():
        if parent_path in vm_config.get("usb_controllers", []):
            return vm_name
    return None



def get_device_xml(controller_path: str) -> str:
    """Generates the libvirt XML for attaching a USB controller.
    Args:
        controller_path: The *parent* device path of the USB controller.
    """
    return f"""
        <hostdev mode="subsystem" type="pci">
            <source>
                <address domain="0x{get_pci_domain(controller_path)}"
                         bus="0x{get_pci_bus(controller_path)}"
                         slot="0x{get_pci_slot(controller_path)}"
                         function="0x{get_pci_function(controller_path)}"/>
            </source>
        </hostdev>
    """

def get_pci_address_parts(device_path: str) -> Optional[Dict[str, str]]:
    """
    Extracts PCI address components (domain, bus, slot, function) from a device path.

    Args:
        device_path: The full device path (e.g.,
            "/sys/devices/pci0000:00/0000:00:14.0").

    Returns:
        A dictionary containing the PCI address parts, or None if extraction fails.
    """
    # The device path should look something like this:
    # /sys/devices/pci0000:00/0000:00:14.0
    parts = device_path.split('/')
    if not parts:
        return None

    pci_device = parts[-1]  # Get the last part, e.g., "0000:00:14.0"
    pci_parts = pci_device.split(':')
    if len(pci_parts) != 3:
        return None

    domain = pci_parts[0]
    bus = pci_parts[1]
    slot_function = pci_parts[2]
    slot = slot_function.split('.')[0]
    function = slot_function.split('.')[1]

    return {
        "domain": domain,
        "bus": bus,
        "slot": slot,
        "function": function,
    }


def get_pci_domain(device_path: str) -> str:
    """Gets the PCI domain from the device path."""
    parts = get_pci_address_parts(device_path)
    return parts["domain"] if parts else "0000"  # Default to "0000" if not found.

def get_pci_bus(device_path: str) -> str:
    """Gets the PCI bus from the device path."""
    parts = get_pci_address_parts(device_path)
    return parts["bus"] if parts else "00"

def get_pci_slot(device_path: str) -> str:
    """Gets the PCI slot from the device path."""
    parts = get_pci_address_parts(device_path)
    return parts["slot"] if parts else "00"

def get_pci_function(device_path: str) -> str:
    """Gets the PCI function from the device path."""
    parts = get_pci_address_parts(device_path)
    return parts["function"] if parts else "0"



def attach_detach_device(vm_name: str, device_xml: str, action: str) -> None:
    """
    Attaches or detaches a device from a VM using virsh.

    Args:
        vm_name: The name of the virtual machine.
        device_xml: The XML description of the device.
        action:  "attach-device" or "detach-device"
    """
    try:
        virsh_command = ["virsh", action, vm_name, "/dev/stdin"]
        log(f"Running virsh command: {virsh_command} with XML: {device_xml}")
        process = subprocess.Popen(
            virsh_command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate(input=device_xml)

        if process.returncode != 0:
            log(
                f"virsh {action} failed with code {process.returncode}.  stdout: {stdout}, stderr:{stderr}"
            )
            print(
                f"Failed to {action} device. Check logs for details.", file=sys.stderr
            )
            sys.exit(1)  # Use sys.exit(1) for a general error
        else:
            log(f"virsh {action} successful. stdout: {stdout}")

    except Exception as e:
        log(f"Exception during virsh {action}: {e}")
        print(f"An error occurred while {action}ing the device: {e}", file=sys.stderr)
        sys.exit(1)  # Use sys.exit(1) for a general error



def main() -> None:
    """Main function to handle USB controller attachment/detachment."""
    device_info = get_device_info()
    if device_info is None:
        log("Failed to get device info, exiting.")
        sys.exit(0)  # Exit cleanly, as this might be a non-USB event.

    log(f"Device information: {device_info}")

    if device_info["action"] not in ["add", "remove"]:
        log(f"Unsupported action: {device_info['action']}")
        sys.exit(0)  # Exit cleanly for unsupported actions

    vm_name = get_vm_config(device_info)
    if vm_name is None:
        log("No matching VM configuration found.")
        sys.exit(0)  # Exit cleanly if no VM is configured for this device.

    # Use the *parent* path (the USB controller).
    parent_path = os.path.dirname(device_info["devpath"])
    if not parent_path:
        log(f"Could not find parent path for {device_info['devpath']}")
        sys.exit(1)

    log(f"Using parent path: {parent_path}")
    device_xml = get_device_xml(parent_path)

    action = "attach-device" if device_info["action"] == "add" else "detach-device"
    attach_detach_device(vm_name, device_xml, action)
    log(f"Successfully handled device {action} for VM {vm_name}")



if __name__ == "__main__":
    main()
