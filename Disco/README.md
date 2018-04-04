# About Disco/CHUCK firmware mod for LTE/4G

Disco drone has autopilot called C.H.U.C.K. It runs linux on ARM hardware. In order it to have a 4G network connection USB 4G dongle has to be connected to CHUCK micro-usb port and CHUCK firmware needs to be modded for dongle hotplugging and for P2P VPN tunneling with SC2/FFP. 

More details about Disco/CHUCK:
* http://ardupilot.org/plane/docs/common-CHUCK-overview.html
* https://github.com/nicknack70/bebop/tree/master/UBHG (althou written for Bebop 2, most of it also applies to Disco)

## Installation

```bash
# upload lte/ subtree to Disco internal000 directory via ftp

# telnet to Disco
telnet 192.168.42.1

# review and when required modify your 4G dongle vendor/product type and interface details
less /data/ftp/internal_000/lte/lib/70-huawei-e3372h-153.rules

# install udev rule for 4G dongle modeswitching (to cdc_ether device)
mount -o remount,rw /
cp /data/ftp/internal_000/lte/lib/70-huawei-e3372h-153.rules /lib/udev/rules.d/
chmod 644 /lib/udev/rules.d/70-huawei-e3372h-153.rules
mount -o remount,ro /

### setup tinc vpn

# set local node vpn tunnel address
NODE_VPN_IPADDR="10.0.0.2"

# change to mod directory tree
cd /data/ftp/internal_000/lte

# make binaries executable
chmod +x bin/*

# create tinc config directories
mkdir -p etc/tinc/hosts

# create tinc config file
cat << 'EOF' > etc/tinc/tinc.conf
Name = disco
AddressFamily = ipv4
Interface = tun0
ConnectTo = cloud
EOF

# create vpn up script
cat << EOF > etc/tinc/tinc-up
ifconfig \$INTERFACE $NODE_VPN_IPADDR netmask 255.255.255.0
EOF

# create vpn down script
cat << 'EOF' > etc/tinc/tinc-down
ifconfig $INTERFACE down
EOF

# make vpn up|down scripts executable
chmod +x etc/tinc/tinc-*

# generate host keys
# accept default file locations
bin/tinc -c etc/tinc generate-keys

# setup host vpn ipaddr
sed -i '1 s/^/Subnet = '$NODE_VPN_IPADDR'\/32\n\n/' etc/tinc/hosts/disco

# NB! Exchange node keys through ftp!
# echo node hosts/ should contain public keys for: cloud rpi disco

# for starting the vpn just plug-in 4G dongle and let udev trigger vpn init scripts
# tincd-init script (re-run safe): /data/ftp/internal_000/lte/bin/tincd-init
```
