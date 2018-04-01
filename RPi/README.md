# About Raspberry Pi for LTE/4G mod

TODO

## Installation

```bash
# install utils
apt-get install tcpdump telnet nano vim android-tools-adb dnsutils screen ncftp

# install avahi-daemon for PISCO discovery
apt-get install avahi-daemon

# install software for PISCO Access Point
apt-get install hostapd dnsmasq wpasupplicant

# install Tinc p2p VPN
apt-get install tinc

# install usb_modeswitch for initializing 4G dongle
apt-get install usb-modeswitch
```

## Configuration

```bash
# verify that kernel IP forwarding has been enabled!
cat /proc/sys/net/ipv4/ip_forward
> example output
1

# power ON your Disco
# AND plug in your RPi USB Wifi dongle

# whats is your USB Wifi dongle interface?
IFACE="wlan0"

# lookup Disco serial from wifi IE field
DISCO_ID="$( iwlist wlan0 scan | awk '/DISCO/' | cut -d'-' -f2 | tr -d '"' )"
echo $DISCO_ID

DISCO_ID_PADDED="$( echo $DISCO_ID | fold -w1 | paste -sd'3' - )"
echo $DISCO_ID_PADDED 

DISCO_IE="$( iwlist wlan0 scan | awk '/'."$DISCO_ID_PADDED".'/ { print $3 }' )"
echo $DISCO_IE

# NB! Change DISCO to PISCO
# AND increment last digit of DISCO_ID and 3rd digit from backwards of DISCO_IE by +1 
# (the Y char in examples)
PISCO_ID="PISCO-XXXXXY"
PISCO_IE="DDXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXY00"

# create hostapd.conf
cat << EOF > /etc/hostapd/hostapd.conf
#AP for PISCO
interface=$IFACE
ssid=$PISCO_ID
ieee80211n=1
# wifi not enrypted atm
#wpa=2
#wpa_passphrase=your_passphrase
#wpa_key_mgmt=WPA-PSK
#rsn_pairwise=CCMP
vendor_elements=$PISCO_IE
hw_mode=g
ignore_broadcast_ssid=0
channel=6
logger_syslog=-1
logger_syslog_level=1
EOF

# create wlan interface configuration file
cat << EOF > /etc/network/interfaces.d/${IFACE}
allow-hotplug $IFACE
auto $IFACE $IFACE:1
iface $IFACE inet static
hostapd /etc/hostapd/hostapd.conf
address 192.168.42.200
netmask 255.255.255.0
 
iface $IFACE:1 inet static
address 192.168.42.1
netmask 255.255.255.0
EOF

# lookup your SC2 macaddr from Disco 
# TODO
SC2_MACADDR="a0:14:3d:ce:c2:4f"

# set static IPADDR for SC2
SC2_IPADDR="192.168.42.50"

# create dnsmasq dhcp server configuration for PISCO AP
cat << EOF > /etc/dnsmasq.d/pisco-ap.conf
interface=lo,$IFACE
no-dhcp-interface=lo
dhcp-range=192.168.42.201,192.168.42.219,255.255.255.0,12h
dhcp-option=3
# SC2 macaddr:static_ip mapping
dhcp-host=$SC2_MACADDR,$SC2_IPADDR
EOF

# restart dnsmasq service
systemctl restart dnsmasq

### add ardiscovery.service to avahi-daemon

# lookup device_id PIXXXXXXXXXXXXXXXY from FFP app (or from Disco avahi_daemon configuration) and increment Y by +1
# and use PISCO_ID as name
cat << 'EOF' > /etc/avahi/services/ardiscovery.service
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
<name replace-wildcards="yes">PISCO-XXXXXY</name>
<service>
<type>_arsdk-090e._udp</type>
<port>44444</port>
<txt-record>{"device_id":"PIXXXXXXXXXXXXXXXY"}</txt-record>
</service>
</service-group>
EOF

# reconfigure avahi-daemon
cp -p /etc/avahi/avahi-daemon.conf /etc/avahi/avahi-daemon.conf.bak
cat << 'EOF' > /etc/avahi/avahi-daemon.conf
[server]
use-ipv4=yes
use-ipv6=yes
ratelimit-interval-usec=1000000
ratelimit-burst=1000
[wide-area]
enable-wide-area=no
[publish]
publish-aaaa-on-ipv4=no
publish-a-on-ipv6=yes
[reflector]
[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=768
rlimit-stack=4194304
rlimit-nproc=3
EOF

# restart avahi-daemon
systemctl restart avahi-daemon

### create tinc vpn configuration

# set local node vpn tunnel address
NODE_VPN_IPADDR="10.0.0.3"

mkdir -p /etc/tinc/vpn0/hosts/

# create tinc configuration
cat << EOF > /etc/tinc/vpn0/tinc.conf
Name = rpi
AddressFamily = ipv4
Interface = tun0
ConnectTo = cloud
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
sed -i '1 s/^/Subnet = '$NODE_VPN_IPADDR'\/32\n\n/' /etc/tinc/vpn0/hosts/rpi

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


### setup 1:1 NAT rules

DISCO_VPN_IPADDR="10.0.0.2"
RPI_VPN_IPADDR="10.0.0.3"
SC2_IPADDR="192.168.42.50"

# clear ALL existing iptables rules 
iptables -F
iptables -F -t nat

# initialize firewall rules
iptables -P FORWARD ACCEPT
iptables -t nat -A PREROUTING -d 192.168.42.1 -j DNAT --to-destination $DISCO_VPN_IPADDR
iptables -t nat -A POSTROUTING -d $RPI_VPN_IPADDR -j SNAT --to-source $RPI_VPN_IPADDR
iptables -t nat -A PREROUTING -d $RPI_VPN_IPADDR -j DNAT --to-destination $SC2_IPADDR
iptables -t nat -A POSTROUTING -d $SC2_IPADDR -j SNAT --to-source 192.168.42.1
iptables -L -n
iptables -L -n -t nat

# make rules persistent
apt-get install iptables-persistent

### configure mode switching for 4G USB dongle

# NB! The following vendor/product IDs are specific to Huawei 3372h-153 dongle
# You may need to alter these according to your model

# unpack hw profiles
cd /usr/share/usb_modeswitch/
tar xvzf configPack.tar.gz

# disable auto-modeswitching by usb_modeswitch wrapper 
# which did not work for me correctly
sed -i.bak 's/^DisableSwitching=0/DisableSwitching=1/' /etc/usb_modeswitch.conf

# enable logging for debugging
sed -i.bak 's/^EnableLogging=0/EnableLogging=1/' /etc/usb_modeswitch.conf

# test dongle modeswitching manually (switching from storage to router mode)
usb_modeswitch -J -v 0x12d1 -p 0x157d

# automate and make persistent (hot-pluggable)
cat << 'EOF' > /etc/udev/rules.d/70-hawei-e3372h-153.rules
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="12d1", ATTRS{idProduct}=="157d", RUN+="/usr/sbin/usb_modeswitch -J -v 0x12d1 -p 0x157d"
EOF
```
