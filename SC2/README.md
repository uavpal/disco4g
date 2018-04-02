# About SkyController 2 firmware mod for LTE/4G

Current (optional but highly recommended) SC2 firmware mod does only one thing: it changes SC2 led to output blue light when connected to Disco drone over 4G datalink.

## Installation

```bash
# on host with adb
# set SC2 IP to connect to
SC2_IPADDR="192.168.42.50"

# upload lte/bin/raspibidge to SC2 over FTP
TODO

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
