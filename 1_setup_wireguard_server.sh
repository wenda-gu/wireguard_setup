#!/bin/bash

# Check if the setup scripts exist
if [ ! -f ./helper/setup_ssh_connection.sh ]; then
    echo "Error: helper/setup_ssh_connection.sh not found in the current directory."
    exit 1
fi

if [ ! -f ./helper/setup_wireguard.sh ]; then
    echo "Error: helper/setup_wireguard.sh not found in the current directory."
    exit 1
fi


# Ask for user input
# SSH
read -p "Enter the username for the remote server, press enter to set as \"root\": " username
read -p "Enter the IP address of the remote server: " ip
read -p "Enter the alias name for the SSH configuration: " alias_name
username=${username:-root}

# Server
read -p "Enter the hostname for the remote server, press enter to set the same as the alias name: " new_hostname
# read -p "Enter the private IP address of the server, press enter to set as \"192.168.6.1/24\": " server_private_ip
# read -p "Enter the port for the server to listen on, press enter to set as \"41194\": " server_port
new_hostname=${new_hostname:-$alias_name}
# server_private_ip=${server_private_ip:-192.168.6.1/24}
# server_port=${server_port:-41194}

echo $new_hostname

### SSH Connection Setup ###
# Execute the SSH setup script
echo "Executing setup_ssh_connection.sh..."
./helper/setup_ssh_connection.sh "$username" "$ip" "$alias_name"

# Check if the SSH setup script executed successfully
if [ $? -eq 0 ]; then
    echo "SSH connection setup completed successfully."
else
    echo "SSH connection setup failed."
    exit 1
fi



### WireGuard Setup ###
# Execute the WireGuard setup script
echo "Executing setup_wireguard.sh remotely..."

script_name="setup_wireguard.sh"
remote_script="/root/$script_name"
# Step 1: Copy the local script to the remote server
scp helper/$script_name $alias_name:$remote_script

# Step 2: Connect to the remote server and execute the remote script with arguments
ssh $alias_name "bash $remote_script $new_hostname $server_private_ip"

# Optional: Remove the remote script after execution
ssh $alias_name "rm $remote_script"

