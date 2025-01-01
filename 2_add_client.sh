#!/bin/bash

read -p "Enter the alias name for the SSH remote server connection: " alias_name
read -p "Enter the device name for the client: " device_name


alias_name_to_ip() {
  # Path to your SSH configuration file
  ssh_config_file="$HOME/.ssh/config"

  # Check if the SSH config file exists
  if [[ ! -f "$ssh_config_file" ]]; then
    echo "SSH config file not found at $ssh_config_file"
    exit 1
  fi

  # Search for the alias in the SSH config and get the corresponding IP address
  ip_address=$(awk -v alias="$alias_name" '
    /Host / { 
      if ($2 == alias) {
        found=1
      } else {
        found=0
      }
    }
    found && /HostName/ { 
      print $2
      exit
    }
  ' "$ssh_config_file")

  # Check if an IP address was found
  if [[ -z "$ip_address" ]]; then
    echo "Alias '$alias_name' not found or no HostName associated with it."
    exit 1
  fi
  echo "$ip_address"
}





script_name="add_client_remote.sh"
remote_script="/root/$script_name"

# Step 1: Copy the local script to the remote server
scp helper/$script_name $alias_name:$remote_script

# Step 2: Connect to the remote server and execute the remote script with arguments
ssh $alias_name "bash $remote_script $device_name $(alias_name_to_ip)"

# Copy the client config to the client machine
scp $alias_name:/etc/wireguard/client.conf ~/Desktop/$device_name-client.conf

# Remove the tmp file after execution
ssh $alias_name "rm $remote_script /etc/wireguard/client.conf"
