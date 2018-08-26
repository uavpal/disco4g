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
# and setup ntp.conf
mount -o remount,rw /
cp /data/ftp/internal_000/lte/lib/70-huawei-e3372h-153.rules /lib/udev/rules.d/
chmod 644 /lib/udev/rules.d/70-huawei-e3372h-153.rules
ln -s /data/ftp/internal_000/lte/etc/ntp.conf  /etc/ntp.conf
mount -o remount,ro /

### setup tinc vpn

# set local node vpn tunnel address and network
NODE_VPN_IPADDR="192.168.42.12"
NODE_VPN_NET="192.168.42.0/24"

# set cloud and rpi vpn peers IP addresses
PEER_VPN_NODES="192.168.42.11 192.168.42.13"

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
echo 1 >/proc/sys/net/ipv4/conf/eth0/proxy_arp
echo 1 >/proc/sys/net/ipv4/conf/$INTERFACE/proxy_arp
EOF

# add peer routes
for PEER in $PEER_VPN_NODES; do echo "ip route add ${PEER}/32 dev $INTERFACE" >> etc/tinc/tinc-up; done

# remove 192.168.42.0/24 -> tun0 route
# (fix for 4g usb unplug wifi reconnect problem)
echo "ip route del 192.168.42.0/24 dev $INTERFACE" >> etc/tinc/tinc-up

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
sed -i '1 s/^/Subnet = '$NODE_VPN_NET'\n\n/' etc/tinc/hosts/disco

# NB! Exchange node keys through ftp!
# echo node hosts/ should contain public keys for: cloud rpi disco

# for starting the vpn just plug-in 4G dongle and let udev trigger vpn init scripts
# tincd-init script (re-run safe): /data/ftp/internal_000/lte/bin/tincd-init
```

## Optional: Limiting Disco video streaming bandwidth

Sometimes you may desire to limit Disco video streaming bandwidth over 4G datalink - because:
* lower quality video = less video lag on datalink (and perhaps more stable stream)
* lower quality video = less bandwidth costs for 4G datalink

Normally Disco streams video to FFPro either 2.4Mbit (when recording resolution is set to 1080p) or 4.8Mbit (when recording resolution is set to 720p). The latter case could mean that Disco streams also in 720p and in case of 1080p recording streaming is set to 480p.

Disco's dragon-prog (ie the autopilot software) has '-q' option - which allows to limit available video streaming bandwidth (does not affect video recording resolution). Video streaming bandwidth limiting seems to work best in 0.8Mbit steps - and its advisable to leave some headroom (+0.2Mbit usually) with bandwith limit cap.

'-q' parameter accepts values in kbits - and some tested values are:
* -q 1800 => resulting 1.6Mbit streaming
* -q 1000 => resulting  0.8Mbit streaming
* -q 600 => resulting 0.6Mbit streaming

Simplest method to set and persist dragon-prog -q parameter is to modify /usr/bin/DragonStarter.sh script in the following way:
```bash
# telnet to Disco (over WIFI)
telnet 192.168.42.1

# make backup copy of /usr/bin/DragonStarter.sh script
cp -p /usr/bin/DragonStarter.sh /data/ftp/internal_000/lte/bin/

# set streaming bandwidth limit as variable
BW_LIMIT="600"

# verify (output should not be empty and match value that was set!)
echo $BW_LIMIT
> example output
600

# re-mount root filesystem in read-write mode - allowing modifications
mount -o remount,rw /

# edit /usr/bin/DragonStarter.sh script
# by replacing line no 7
# DEFAULT_PROG="usr/bin/dragon-prog"
# with
# DEFAULT_PROG="usr/bin/dragon-prog -q 600"
sed -i.bak "s/^DEFAULT_PROG=.*/DEFAULT_PROG=\"usr\/bin\/dragon-prog -q $BW_LIMIT\"/g" /usr/bin/DragonStarter.sh

# verify change
less /usr/bin/DragonStarter.sh

# re-mount root filesystem in read-only mode - as it was before
mount -o remount,ro /

# reboot Disco for changes to take effect
reboot
```

## Optional: Setup Disco real-time tracking map with glympse.com

Glympse.com provides REST API and web/mobile apps for real-time GPS tracking.
Integration scripts provide the following:
* Hilink 4G modem signal strength reading
* Disco altitude reading
* Location tracking

In order to enable glympse.com integration create a free Glympse Developer account at https://developer.glympse.com/account/create:

* Complete the form using a valid e-mail address.
* Once verification e-mail is sent, click the "Verify Sign-up" link inside.
* You will see "Your account has now been verified. Welcome aboard!"
* Click "MY ACCOUNT" on top right and the "My Apps"
* Click "New Application (+)"
* Application Name: uavpal softmod
* Platform: Web API
* OS: Other
* Click "Create"

You should see the newly generated API Key now (20 characters), note it down as we need it later.

In order to enable glympse.com tracking integration do the following:
* insert Glympse API key into: /data/ftp/internal_000/lte/etc/glympse_apikey
* insert your phonenumber to receive Glympse tracking link via SMS here: /data/ftp/internal_000/lte/etc/phonenumber  
