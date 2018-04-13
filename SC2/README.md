# About SkyController 2 firmware mod for LTE/4G

Current (optional but highly recommended) SC2 firmware mod does only one thing: it changes SC2 led to output blue light when connected to Disco drone over 4G datalink.

## Development environment

* USB 2.0 Ethernet adapter with ASIX AX88772 chipset onboard, connected to SC2 USB and to LAN router that provides DHCP service. Apple MC704LL/A, MC704ZM/A and Edimax EU-4208 adapters are known to work with SC2 out-of-the-box. SC2 will issue dhcp request once adapter is connected. You need to lookup SC2 IP from LAN router/dhcp server.
* You need to use Android Debug Bridge in order to connect to SC2 (on tcp/9050 port):
```bash
# Installing ADB on MacOSX using brew (https://brew.sh/)
brew tap caskroom/cask
brew cask install android-platform-tools

# connect adb to SC2
SC2_IPADDR="XXX.XXX.XX.XX"
adb connect $SC2_IPADDR:9050

# get shell access on SC2
adb shell

# exit & disconnect when done
exit
adb disconnect $SC2_IPADDR:9050
```
* NB! USB 2.0 hubs seem to work with SC2 - but FFP/phone over usb hub does not!

## Installation

```bash
# on host with adb
# set SC2 IP to connect to
SC2_IPADDR="192.168.42.50"
	
# upload lte/ subtree to SC2 ftp root (ftp://$SC2_IPADDR:21/)

# connect to SC2 with Android Debug Bridge
adb connect $SC2_IPADDR:9050
adb shell

# make rasbibridge script executable
chmod +x /data/lib/ftp/lte/bin/raspibridge

# make rootfs writable
mount -o remount,rw /

# edit mppd init file and add rasbibridge service
vi /etc/boxinit.d/99-mppd.rc
--- ADD ---
service raspid /data/lib/ftp/lte/bin/raspibridge
     class mpp
     user root
--- ADD ---

# make rootfs read-only again
mount -o remount,ro /

# logout
exit

# disconnect adb
adb disconnect $SC2_IPADDR:9050

# power off/on SC2 for raspibridge service to start
```
