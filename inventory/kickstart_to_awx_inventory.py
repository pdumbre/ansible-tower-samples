#!/usr/bin/env python3
"""
Convert kickstart.json to AWX/Ansible inventory YAML format.

This script parses the kickstart.json file containing rack configuration
and generates an AWX-compatible inventory YAML file with BMC servers,
switches, and provisioners organized into appropriate groups.

Usage:
    python kickstart_to_awx_inventory.py kickstart.json output_inventory.yml
"""

import json
import yaml
import sys
import base64
from pathlib import Path


def decode_password(encoded_password):
    """Decode base64 encoded password."""
    try:
        return base64.b64decode(encoded_password).decode('utf-8')
    except Exception as e:
        print(f"Warning: Failed to decode password: {e}")
        return encoded_password


def extract_ru_number(location):
    """Extract RU number from location string (e.g., 'RU2' -> 2)."""
    if location and location.startswith('RU'):
        return location[2:]
    return location


def convert_kickstart_to_inventory(kickstart_data):
    """
    Convert kickstart.json to AWX inventory format.
    
    Args:
        kickstart_data: Parsed kickstart.json data
        
    Returns:
        Dictionary in AWX inventory format
    """
    inventory = {
        "all": {
            "children": {
                "jump_hosts": {
                    "hosts": {}
                },
                "bmc_servers": {
                    "hosts": {},
                    "vars": {
                        "ansible_user": "USERID",
                        "ansible_password": "{{ vault_imm_password }}",
                        "bmc_jump_host": "mgen",
                        "bmc_network_interface": "eno2",
                        "bmc_ssh_options": "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=30",
                        "powerrp": "restore",
                        "failover_mode": "shared"
                    }
                },
                "switches": {
                    "hosts": {},
                    "vars": {
                        "ansible_user": "cumulus",
                        "ansible_password": "{{ vault_switch_password }}",
                        "ansible_connection": "network_cli",
                        "ansible_network_os": "cumulus"
                    }
                },
                "tor_switches": {
                    "hosts": {}
                },
                "mgmt_switches": {
                    "hosts": {}
                },
                "provisioners": {
                    "hosts": {},
                    "vars": {
                        "ansible_user": "root",
                        "ansible_password": "{{ vault_provisioner_password }}"
                    }
                },
                "storage_nodes": {
                    "hosts": {}
                },
                "compute_nodes": {
                    "hosts": {}
                },
                "service_nodes": {
                    "hosts": {}
                }
            }
        }
    }
    
    # Process rack info
    rack_info = kickstart_data.get("rackInfo", {})
    rack_serial = rack_info.get("serial", "unknown")
    
    # Add jump host (mgen) - typically the provisioner or management node
    # For now, we'll add a placeholder that should be configured manually
    inventory["all"]["children"]["jump_hosts"]["hosts"]["mgen"] = {
        "ansible_host": "10.48.112.47",  # Update with actual IP
        "ansible_user": "root",
        "ansible_ssh_private_key_file": "/runner/.ssh/id_rsa",
        "ansible_ssh_common_args": "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    }
    
    # Process compute node BMCs
    compute_nodes = kickstart_data.get("computeNodeIntegratedManagementModules", [])
    
    for node in compute_nodes:
        node_name = node.get("name", "unknown")
        location = node.get("location", "")
        ru_number = extract_ru_number(location)
        node_type = node.get("type", "compute")
        
        # Generate hostname
        hostname = f"node_ru{ru_number}"
        
        # Extract IPv6 addresses
        ipv6_ula = node.get("ipv6ULA", "")
        ipv6_lla = node.get("ipv6LLA", "")
        
        # For AWX, we'll use a placeholder IPv4 or the last octet of IPv6
        # In production, you'd need actual IPv4 addresses or configure IPv6 properly
        # Using 169.253.1.x pattern as seen in the conversation
        ansible_host = f"169.253.1.{ru_number}"
        
        # Extract user credentials
        users = node.get("users", [])
        userid_user = next((u for u in users if u.get("user") == "USERID"), None)
        
        # Build host entry
        host_entry = {
            "ansible_host": ansible_host,
            "bmc_ipv6_address": ipv6_ula,
            "bmc_lla_ip": ipv6_lla,
            "ru_number": int(ru_number) if ru_number.isdigit() else ru_number,
            "node_type": node_type,
            "serial_number": node.get("serialNum", ""),
            "mtm": node.get("mtm", ""),
            "ibm_serial_number": node.get("ibmSerialNumber", ""),
            "ibm_mtm": node.get("ibmMTM", ""),
            "uuid": node.get("uuid", ""),
            "location": location
        }
        
        # Add network interface information
        network_interfaces = node.get("networkInterfaces", [])
        if network_interfaces:
            for idx, iface in enumerate(network_interfaces):
                if iface.get("interfaceType") == "provisioning":
                    host_entry["provisioning_mac"] = iface.get("macAddress", "")
                    host_entry["provisioning_interface"] = iface.get("interfaceName", "")
                elif iface.get("interfaceType") == "baremetal":
                    host_entry["baremetal_mac"] = iface.get("macAddress", "")
                    host_entry["baremetal_interface"] = iface.get("interfaceName", "")
        
        # Add to appropriate groups
        inventory["all"]["children"]["bmc_servers"]["hosts"][hostname] = host_entry
        
        # Add to type-specific group
        if node_type == "storage":
            inventory["all"]["children"]["storage_nodes"]["hosts"][hostname] = {}
        elif node_type == "compute":
            inventory["all"]["children"]["compute_nodes"]["hosts"][hostname] = {}
        elif node_type == "servicenode":
            inventory["all"]["children"]["service_nodes"]["hosts"][hostname] = {}
    
    # Process switches
    switches = kickstart_data.get("switches", [])
    
    for switch in switches:
        switch_name = switch.get("name", "unknown")
        location = switch.get("location", "")
        switch_type = switch.get("switch_type", "")
        
        # Extract IPv6 address
        ipv6 = switch.get("ipv6", "")
        
        # For AWX, use a placeholder IPv4 or configure IPv6
        # Switches typically have management IPs
        ansible_host = ipv6  # Or map to IPv4 if available
        
        # Extract credentials
        users = switch.get("users", [])
        cumulus_user = next((u for u in users if u.get("user") == "cumulus"), None)
        
        # Build switch entry
        switch_entry = {
            "ansible_host": ansible_host,
            "serial_number": switch.get("serial", ""),
            "ibm_serial_number": switch.get("ibmSerialNumber", ""),
            "ibm_mtm": switch.get("ibmMTM", ""),
            "model": switch.get("model", ""),
            "mac_address": switch.get("macAddr", ""),
            "location": location,
            "switch_type": switch_type,
            "manufacturer": switch.get("manufacturer", ""),
            "software_version": switch.get("softver", "")
        }
        
        # Add to switches group
        inventory["all"]["children"]["switches"]["hosts"][switch_name] = switch_entry
        
        # Add to type-specific group
        if switch_type == "tor_network_switch":
            inventory["all"]["children"]["tor_switches"]["hosts"][switch_name] = {}
        elif switch_type == "internal_management_switch":
            inventory["all"]["children"]["mgmt_switches"]["hosts"][switch_name] = {}
    
    # Process provisioners
    provisioners = kickstart_data.get("provisioners", [])
    
    for provisioner in provisioners:
        prov_name = provisioner.get("name", "unknown")
        location = provisioner.get("location", "")
        ipv6 = provisioner.get("ipv6", "")
        
        # Extract credentials
        users = provisioner.get("users", [])
        root_user = next((u for u in users if u.get("user") == "root"), None)
        
        # Build provisioner entry
        prov_entry = {
            "ansible_host": ipv6,  # Or map to IPv4
            "location": location,
            "bootstrap_mac": provisioner.get("bootstrapMACAddress", "")
        }
        
        inventory["all"]["children"]["provisioners"]["hosts"][prov_name] = prov_entry
    
    return inventory


def write_yaml(output_path, data):
    """Write inventory data to YAML file."""
    with open(output_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, width=120)


def main():
    """Main function."""
    if len(sys.argv) != 3:
        print("Usage: python kickstart_to_awx_inventory.py kickstart.json output_inventory.yml")
        print("\nExample:")
        print("  python kickstart_to_awx_inventory.py /path/to/kickstart.json inventory/hosts.yml")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    # Validate input file exists
    if not Path(input_file).exists():
        print(f"Error: Input file '{input_file}' not found")
        sys.exit(1)
    
    try:
        # Load kickstart JSON
        print(f"Loading kickstart data from: {input_file}")
        with open(input_file, 'r') as f:
            kickstart_data = json.load(f)
        
        # Convert to inventory format
        print("Converting to AWX inventory format...")
        inventory = convert_kickstart_to_inventory(kickstart_data)
        
        # Write output YAML
        print(f"Writing inventory to: {output_file}")
        write_yaml(output_file, inventory)
        
        # Print summary
        bmc_count = len(inventory["all"]["children"]["bmc_servers"]["hosts"])
        switch_count = len(inventory["all"]["children"]["switches"]["hosts"])
        prov_count = len(inventory["all"]["children"]["provisioners"]["hosts"])
        
        print("\n✅ Inventory YAML created successfully!")
        print(f"\nSummary:")
        print(f"  - BMC Servers: {bmc_count}")
        print(f"  - Switches: {switch_count}")
        print(f"  - Provisioners: {prov_count}")
        print(f"\nOutput file: {output_file}")
        print("\n⚠️  Note: Please update the following:")
        print("  1. Jump host (mgen) IP address and credentials")
        print("  2. Vault variables for passwords (vault_imm_password, vault_switch_password, etc.)")
        print("  3. IPv4 addresses for BMCs if not using IPv6")
        print("  4. Verify all network interface names match your environment")
        
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in input file: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
