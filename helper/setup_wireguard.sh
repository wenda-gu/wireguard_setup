#!/bin/bash

# Get input
new_hostname=$1
server_private_ip=192.168.6.1/24
server_port=41194
subnet=192.168.6.0/24
# server_private_ip=$2
# server_port=$3


### Prepare Server ###
# Change hostname
echo $new_hostname
hostnamectl set-hostname $new_hostname

# Customize terminal prompt
cat << 'EOF' >> "/root/.bashrc"
PS1="\[\033[1m\]\`if [ \$? = 0 ]; then echo \[\e[32m\]; else echo \[\e[31m\]; fi\`██ \[\e[35m\]\u@\h\[\e[30m\]:\[\e[33m\]\W\[\e[37m\]\[\033[m\] $ "
export PS1
EOF

# Update system
apt update && apt upgrade -y



### WireGuard Setup ###
# Install WireGuard
apt install wireguard -y

# Generate key pairs
mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key

# Write WireGuard config file: /etc/wireguard/wg0.conf
cat << EOF > "/etc/wireguard/wg0.conf"
[Interface]
Address = $server_private_ip
ListenPort = $server_port
PrivateKey = $(cat server_private.key)
SaveConfig = false
PostUp = /etc/wireguard/helper/add-nat-routing.sh
PostDown = /etc/wireguard/helper/remove-nat-routing.sh
EOF

# Set Up WireGuard Firewall Rules

mkdir -p /etc/wireguard/helper

# Write /etc/wireguard/helper/add-nat-routing.sh
cat << EOF > "/etc/wireguard/helper/add-nat-routing.sh"
#!/bin/bash
IPT="/sbin/iptables"
IPT6="/sbin/ip6tables"          

IN_FACE="eth0"                   # NIC connected to the internet
WG_FACE="wg0"                    # WG NIC 
SUB_NET="$subnet"         # WG IPv4 sub/net aka CIDR
WG_PORT="$server_port"                  # WG udp port
# SUB_NET_6="fd42:42:42:42::/112"  # WG IPv6 sub/net

## IPv4 ##
\$IPT -t nat -I POSTROUTING 1 -s \$SUB_NET -o \$IN_FACE -j MASQUERADE
\$IPT -I INPUT 1 -i \$WG_FACE -j ACCEPT
\$IPT -I FORWARD 1 -i \$IN_FACE -o \$WG_FACE -j ACCEPT
\$IPT -I FORWARD 1 -i \$WG_FACE -o \$IN_FACE -j ACCEPT
\$IPT -I INPUT 1 -i \$IN_FACE -p udp --dport \$WG_PORT -j ACCEPT

## IPv6 (Uncomment) ##
## \$IPT6 -t nat -I POSTROUTING 1 -s \$SUB_NET_6 -o \$IN_FACE -j MASQUERADE
## \$IPT6 -I INPUT 1 -i \$WG_FACE -j ACCEPT
## \$IPT6 -I FORWARD 1 -i \$IN_FACE -o \$WG_FACE -j ACCEPT
## \$IPT6 -I FORWARD 1 -i \$WG_FACE -o \$IN_FACE -j ACCEPT
EOF

# Write /etc/wireguard/helper/remove-nat-routing.sh
cat << EOF > "/etc/wireguard/helper/remove-nat-routing.sh"
#!/bin/bash
IPT="/sbin/iptables"
IPT6="/sbin/ip6tables"          
 
IN_FACE="eth0"                   # NIC connected to the internet
WG_FACE="wg0"                    # WG NIC 
SUB_NET="$subnet"            # WG IPv4 sub/net aka CIDR
WG_PORT="$server_port"                  # WG udp port
# SUB_NET_6="fd42:42:42:42::/112"  # WG IPv6 sub/net
 
# IPv4 rules #
\$IPT -t nat -D POSTROUTING -s \$SUB_NET -o \$IN_FACE -j MASQUERADE
\$IPT -D INPUT -i \$WG_FACE -j ACCEPT
\$IPT -D FORWARD -i \$IN_FACE -o \$WG_FACE -j ACCEPT
\$IPT -D FORWARD -i \$WG_FACE -o \$IN_FACE -j ACCEPT
\$IPT -D INPUT -i \$IN_FACE -p udp --dport \$WG_PORT -j ACCEPT
 
# IPv6 rules (uncomment) #
## \$IPT6 -t nat -D POSTROUTING -s \$SUB_NET_6 -o \$IN_FACE -j MASQUERADE
## \$IPT6 -D INPUT -i \$WG_FACE -j ACCEPT
## \$IPT6 -D FORWARD -i \$IN_FACE -o \$WG_FACE -j ACCEPT
## \$IPT6 -D FORWARD -i \$WG_FACE -o \$IN_FACE -j ACCEPT
EOF

# Make port forwarding scripts executable
chmod -v +x /etc/wireguard/helper/*.sh

# Enable IP Forwarding
echo 'net.ipv4.ip_forward=1' | tee -a /etc/sysctl.d/10-wireguard.conf
echo 'net.ipv6.conf.all.forwarding=1' | tee -a /etc/sysctl.d/10-wireguard.conf

# Reload changes using the sysctl command #
sysctl -p /etc/sysctl.d/10-wireguard.conf

# UFW Firewall Setup
ufw allow $server_port/udp
ufw allow 22/tcp
ufw --force enable

# Start WireGuard
systemctl start wg-quick@wg0

# Enable WireGuard on boot
systemctl enable wg-quick@wg0

# Get the service status
systemctl status wg-quick@wg0
