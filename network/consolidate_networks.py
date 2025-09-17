import sys
import ipaddress
#cat networks.txt | python consolidate_networks.py
#python consolidate_networks.py networks.txt
def consolidate_networks(network_list):
    """
    Takes a list of network strings in CIDR format, identifies overlaps,
    and returns a minimal list of the largest covering networks.

    Args:
        network_list: A list of strings, where each string is an IP network
                      in CIDR notation (e.g., '192.168.1.0/24').

    Returns:
        A list of ipaddress network objects representing the consolidated
        networks.
    """
    # A set is used here to automatically handle duplicate input lines.
    networks = set()
    for line in network_list:
        # Sanitize each line by removing leading/trailing whitespace.
        net_str = line.strip()
        # Ignore empty lines or lines that are commented out.
        if not net_str or net_str.startswith('#'):
            continue
        try:
            # Convert the string to a network object.
            # The 'strict=False' flag is not needed here as we are defining networks.
            # It handles both IPv4 and IPv6 automatically.
            networks.add(ipaddress.ip_network(net_str))
        except ValueError:
            # If a line is not a valid network, print an error and skip it.
            print(f"Warning: Skipping invalid network entry '{net_str}'", file=sys.stderr)

    # This is the core of the solution. The collapse_addresses function
    # takes an iterable of network objects and returns a new iterable
    # with all overlapping and adjacent networks merged into their
    # smallest possible supernet. This perfectly solves the problem of
    # keeping the "larger" of two overlapping networks.
    consolidated = list(ipaddress.collapse_addresses(networks))

    # The result is already sorted by network address from the function.
    return consolidated

def main():
    """
    Main function to run the script. Reads networks from a file specified
    as a command-line argument or from standard input if no file is given.
    """
    # Check if a filename was provided on the command line.
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
        try:
            with open(input_file, 'r') as f:
                lines = f.readlines()
        except FileNotFoundError:
            print(f"Error: File not found at '{input_file}'", file=sys.stderr)
            sys.exit(1)
    else:
        # If no file is specified, read from standard input.
        # This allows for piping data, e.g., `cat networks.txt | python consolidate_networks.py`
        print("Reading networks from standard input. Press Ctrl+D (or Ctrl+Z on Windows) to end.", file=sys.stderr)
        lines = sys.stdin.readlines()

    # Get the consolidated list of networks.
    final_networks = consolidate_networks(lines)

    # Print the final, consolidated list to standard output.
    print("\n--- Consolidated Networks ---")
    if not final_networks:
        print("No valid networks were found.")
    else:
        for net in final_networks:
            print(net)

if __name__ == "__main__":
    main()
