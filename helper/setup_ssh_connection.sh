#!/bin/bash

# Get input
username=$1
ip=$2
alias_name=$3


# Check if an SSH key pair exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "No SSH key pair found. Generating a new key pair..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
else
    echo "SSH key pair already exists."
fi

# Copy the public key to the remote server
echo "Copying the SSH key to the remote server..."
ssh-copy-id -i ~/.ssh/id_rsa.pub "$username@$ip"

# Check if the key copy was successful
if [ $? -eq 0 ]; then
    echo "SSH key successfully copied to the remote server."
else
    echo "Failed to copy SSH key. Please check your username, IP address, and password."
    exit 1
fi

# Add the connection to the SSH config file
ssh_config=~/.ssh/config
echo "Updating the SSH config file..."
{
    echo ""
    echo "Host $alias_name"
    echo "    HostName $ip"
    echo "    User $username"
    echo "    IdentityFile ~/.ssh/id_rsa"
} >> "$ssh_config"

echo "SSH configuration updated. You can now connect to the server using:"
echo "ssh $alias_name"
