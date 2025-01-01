#!/bin/bash

read -p "Enter the alias name for the SSH connection you want to delete: " alias_name

# Path to your SSH configuration file
ssh_config_file="$HOME/.ssh/config"

alias_name_to_ip() {
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

server_ip=$(alias_name_to_ip)

# Check if the alias is resolved to an IP
if [ -z "$server_ip" ]; then
  echo "Error: Unable to resolve alias '$alias_name' to an IP address."
  exit 1
fi

# Delete from the SSH config file (~/.ssh/config)
# This removes the block starting from Host <alias_name> to the next "Host" line
# On macOS, the -i flag with sed requires an argument (usually a suffix for backup files). 
# If you’re using macOS and don’t provide a suffix, it may not work as expected. 
# You can use an empty string for the suffix: ''
sed -i '' "/^Host ${alias_name}$/,/^Host /d" $ssh_config_file

# Delete from the known_hosts file by IP address
ssh-keygen -R ${server_ip}

echo "Removed ${alias_name} from ~/.ssh/config and ~/.ssh/known_hosts"
