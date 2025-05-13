#!/usr/bin/python3
import subprocess
import os
import re
import sys
from pathlib import Path

# Path to the qemu_usb_passthrough_script.py
QEMU_USB_SCRIPT_PATH = "/usr/local/sbin/usb-passthrough.py"
# Path to the udev rules file
UDEV_RULES_PATH = "/etc/udev/rules.d/99-usb-passthrough.rules"


def log(message: str) -> None:
    """Logs messages to stderr."""
    print(message, file=sys.stderr)


def get_usb_controller_info() -> list[str]:
    """
    Retrieves information about USB controllers in the system using lspci.

    Returns:
        A list of USB controller paths (e.g.,
        "/sys/devices/pci0000:00/0000:00:14.0"), or an empty list on error.
    """
    try:
        result = subprocess.run(
            ["lspci", "-vmm"], capture_output=True, text=True, check=True
        )
        output = result.stdout
    except subprocess.CalledProcessError as e:
        log(f"Error running lspci: {e}")
        return []

    controllers = []
    # Parse the lspci output
    for device_entry in output.strip().split("\n\n"):
        lines = device_entry.split("\n")
        device_dict = {}
        for line in lines:
            if ":" in line:
                key, value = line.split(":", 1)
                device_dict[key.strip()] = value.strip()
        if "Class" in device_dict and "USB controller" in device_dict["Class"]:
            pci_bus = device_dict["Bus"]
            # Construct the sysfs path.  This is the crucial part.
            controller_path = f"/sys/bus/pci/devices/{pci_bus}"
            # Resolve any symlinks to get the canonical path
            try:
                controller_path = str(Path(controller_path).resolve())
                controllers.append(controller_path)
            except OSError as e:
                log(f"Error resolving path {controller_path}: {e}")
                continue
    return controllers



def update_config_file(controller_paths: list[str], vm_name: str) -> None:
    """
    Updates the CONFIG section in the qemu_usb_passthrough_script.py file.

    Args:
        controller_paths: A list of USB controller paths.
        vm_name: The name of the virtual machine.
    """
    if not os.path.exists(QEMU_USB_SCRIPT_PATH):
        log(f"Error: {QEMU_USB_SCRIPT_PATH} not found.")
        return

    try:
        # Read the entire script content
        with open(QEMU_USB_SCRIPT_PATH, "r") as f:
            lines = f.readlines()

        # Find the CONFIG section
        config_start_line = -1
        config_end_line = -1
        for i, line in enumerate(lines):
            if "CONFIG = {" in line:
                config_start_line = i
            elif "}" in line and config_start_line != -1:
                config_end_line = i
                break

        if config_start_line == -1 or config_end_line == -1:
            log(f"Error: Could not find CONFIG section in {QEMU_USB_SCRIPT_PATH}")
            return

        # Construct the new CONFIG section
        new_config = f'CONFIG = {{\n    "{vm_name}": {{\n        "usb_controllers": [\n'
        for path in controller_paths:
            new_config += f'            "{path}",\n'
        new_config += "        ],\n    },\n}\n"

        # Replace the old CONFIG section with the new one
        lines = (
            lines[:config_start_line]
            + [new_config]
            + lines[config_end_line + 1 :]
        )

        # Write the modified content back to the script
        with open(QEMU_USB_SCRIPT_PATH, "w") as f:
            f.writelines(lines)

        log(f"Successfully updated CONFIG in {QEMU_USB_SCRIPT_PATH}")

    except Exception as e:
        log(f"Error updating config file: {e}")



def update_udev_rules(controller_paths: list[str]) -> None:
    """
    Creates or updates the udev rules file to handle USB controller events.

    Args:
        controller_paths: A list of USB controller paths.
    """
    # Get driver for each controller.  Crucial for the udev rule.
    drivers = set()
    for controller_path in controller_paths:
        driver = get_pci_driver(controller_path)
        if driver:
            drivers.add(driver)
        else:
            log(f"Warning: Could not determine driver for {controller_path}")

    if not drivers:
        log("Error: No USB controller drivers found.")
        return

    # Construct the udev rule.  Handle multiple drivers if necessary.
    rule_content = (
        'ACTION=="add|remove", SUBSYSTEM=="pci", DRIVER=="'
        + '", DRIVER=="'.join(drivers)
        + '", RUN+="'
        + QEMU_USB_SCRIPT_PATH
        + '"\n'
    )

    try:
        # Write the udev rule to the file
        with open(UDEV_RULES_PATH, "w") as f:
            f.write(rule_content)
        log(f"Successfully updated udev rules in {UDEV_RULES_PATH}")
    except Exception as e:
        log(f"Error updating udev rules: {e}")



def get_pci_driver(device_path: str) -> Optional[str]:
    """
    Gets the PCI driver for a given device path.

    Args:
        device_path: The path to the PCI device in sysfs (e.g.,
        "/sys/devices/pci0000:00/0000:00:14.0").

    Returns:
        The name of the driver, or None if it cannot be determined.
    """
    driver_link = os.path.join(device_path, "driver")
    if os.path.exists(driver_link):
        try:
            # Read the target of the symlink
            driver_path = os.readlink(driver_link)
            return os.path.basename(driver_path)  # Get the driver name
        except OSError as e:
            log(f"Error reading driver link {driver_link}: {e}")
            return None
    else:
        return None



def main() -> None:
    """Main function to orchestrate the configuration update."""
    controller_paths = get_usb_controller_info()
    if not controller_paths:
        log("Error: No USB controllers found.")
        sys.exit(1)

    log(f"Found USB controllers: {controller_paths}")

    vm_name = input("Enter the name of the QEMU/libvirt VM: ")
    update_config_file(controller_paths, vm_name)
    update_udev_rules(controller_paths)

    # Print a helpful message to the user, including the script path.
    print(
        "Configuration updated.  Please restart your udev service and"
        f" ensure that {QEMU_USB_SCRIPT_PATH} is executable"
        " (chmod +x /usr/local/sbin/usb-passthrough.py)."
    )



if __name__ == "__main__":
    main()
