#!/bin/sh
echo "=== Uninstalling Disco4G on Skycontroller 2 ==="
ip_sc2=`netstat -nu |grep 9988 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
chmod +x /tmp/disco4g/disco/uavpal/bin/adb
until /tmp/disco4g/disco/uavpal/bin/adb connect ${ip_sc2}:9050 2>/dev/null;
do
	echo "Trying to connect from Disco to Skycontroller 2 via Wi-Fi"
done
echo "Remounting filesystem as read/write"
/tmp/disco4g/disco/uavpal/bin/adb shell "mount -o remount,rw /" 2>/dev/null
echo "Removing init script for softmod"
/tmp/disco4g/disco/uavpal/bin/adb shell "rm -f /etc/boxinit.d/99-uavpal.rc" 2>/dev/null
echo "Remounting filesystem as read-only"
/tmp/disco4g/disco/uavpal/bin/adb shell "mount -o remount,ro /" 2>/dev/null
echo "Removing zerotier-one data"
/tmp/disco4g/disco/uavpal/bin/adb shell "rm -rf /data/lib/zerotier-one" 2>/dev/null
echo "Removing uavpal softmod files"
/tmp/disco4g/disco/uavpal/bin/adb shell "rm -rf /data/lib/ftp/uavpal" 2>/dev/null
echo "All done! :)"
echo
