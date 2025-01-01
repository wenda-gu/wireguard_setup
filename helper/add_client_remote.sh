#!/bin/bash

device_name=$1
server_public_ip=$2
server_config="wg0.conf"

cd /etc/wireguard


### Parse wg0.conf to get listen port and generate a non-conflicting private ip for client
extract_listen_port() {
  # Extract the ListenPort value from the WireGuard config file
  listen_port=$(grep -i "^ListenPort" "$server_config" | awk '{print $3}')

  # Check if a ListenPort was found
  if [[ -z "$listen_port" ]]; then
    echo "ListenPort not found in the config file."
    return 1
  fi

  # Return the ListenPort
  echo "$listen_port"
}

# Function to extract the subnet from the Address field in the [Interface] section
extract_subnet() {
  subnet=$(awk '/\[Interface\]/{flag=1} flag && /Address/ {print $3; exit}' "$server_config")
  
  if [[ -z "$subnet" ]]; then
    echo "Error: Subnet not found in the configuration file"
    exit 1
  fi
  
  # Remove the CIDR (e.g., /24) from the subnet address
  subnet="${subnet%.*}"
  echo "$subnet"
}


subnet=$(extract_subnet)

existing_ips=()

# Extract existing IP addresses from the WireGuard configuration file
while read -r line; do
  # Check for lines containing "AllowedIPs" and extract the IP addresses
  if [[ "$line" =~ AllowedIPs\ =\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/32 ]]; then
    existing_ips+=("${BASH_REMATCH[1]}")
  fi
done < "$server_config"

# Function to generate a random IP address within the subnet and avoid conflicts
generate_ip() {
  while true; do
    # Generate a random IP between 2 and 254 (avoiding .1 as it is reserved for the server)
    new_ip="${subnet}.$((RANDOM % 254 + 2))"
    
    # Check if the IP already exists in the list
    if [[ ! " ${existing_ips[@]} " =~ " $new_ip " ]]; then
      echo "$new_ip"
      return
    fi
  done
}


listen_port=$(extract_listen_port)
new_client_private_ip=$(generate_ip)
wg genkey | tee client_private.key | wg pubkey > client_public.key

# Add client info in wg0.conf
cat << EOF >> "$server_config"

# $device_name
[Peer]
AllowedIPs = $new_client_private_ip/32
PublicKey = $(cat client_public.key)
EOF

# Create client config file
cat << EOF > "client.conf"
[Interface]
PrivateKey = $(cat client_private.key)
Address = $new_client_private_ip/24
DNS = 1.1.1.1

[Peer]
PublicKey = $(cat server_public.key)
AllowedIPs = 0.0.0.0/0
Endpoint = $server_public_ip:$listen_port
PersistentKeepalive = 15
EOF

# Restart WireGuard service to apply the changes
systemctl restart wg-quick@wg0.service

# Clean up
rm client_private.key client_public.key
