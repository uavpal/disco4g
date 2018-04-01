# About VPN Server for LTE/4G mod

Required to broker VPN clients behind NATed connections that cannot connect directly (which is normally the case with LTE/4G clients). There has to be at least one VPN node with public IP address that other nodes can connect to. Low cost cloud VM with public IP from AWS or DigitalOcean would do. Alternatively you can provide 1:1 NATed public IP address one of the VPN nodes 4G connection (aka disco or rpi) - if your carrier offers this.

TODO

## Installation

* https://www.cyberciti.biz/faq/how-to-install-tinc-vpn-on-ubuntu-linux-16-04-to-secure-traffic/

```bash
# We assume Ubuntu 16.04 OS here
apt-get install tinc

# set local node vpn tunnel address
NODE_VPN_IPADDR="10.0.0.1"
# lookup your server public IP 
NODE_PUB_IPADDR="XXX.XXX.XXX.XXX"

mkdir -p /etc/tinc/vpn0/hosts/

# create tinc configuration
cat << EOF > /etc/tinc/vpn0/tinc.conf
Name = cloud
AddressFamily = ipv4
Interface = tun0
EOF

# create vpn up script
cat << EOF > /etc/tinc/vpn0/tinc-up
ifconfig \$INTERFACE $NODE_VPN_IPADDR netmask 255.255.255.0
EOF

# create vpn down script
cat << 'EOF' > /etc/tinc/vpn0/tinc-down
ifconfig $INTERFACE down
EOF

# make vpn up|down scripts executable
chmod -v +x /etc/tinc/vpn0/tinc-{up,down}

# generate host keys
# accept default file locations
tincd --net=vpn0 --generate-keys

# setup host vpn ipaddr
sed -i '1 s/^/Address = '$NODE_PUB_IPADDR'\nSubnet = '$NODE_VPN_IPADDR'\/32\n\n/' /etc/tinc/vpn0/hosts/cloud

# NB! Exchange host public keys (ie keys under hosts/ on each node) with other nodes!

# set vpn network to be controlled by init scripts
echo 'vpn0' >> /etc/tinc/nets.boot

# start tinc vpn0 network
systemctl start tinc@vpn0.service

# verify
systemctl status tinc

# enable on boot
systemctl enable tinc
systemctl enable tinc@vpn0.service

# NB! You may need to set also firewall rules, depending on your server provider and VM OS configuration
# tcp/655
# udp/655
```
