#!/bin/sh
echo "=== Uninstalling UAVPAL softmod on Skycontroller 2 ==="
chmod +x /tmp/*4g/*/uavpal/bin/adb
until [ "$ip_sc2" != "" ]; do
	ip_sc2=`netstat -nu |grep 9988 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
	echo "Trying to detect Skycontroller 2 (ensure Skycontroller 2 is turned on and its power LED is green)"
	sleep 1
done

/tmp/*4g/*/uavpal/bin/adb start-server 2>/dev/null

echo "Trying to connect to Skycontroller 2 ($ip_sc2) via adb"
until [ $(/tmp/*4g/*/uavpal/bin/adb connect ${ip_sc2}:9050 2>/dev/null | grep 'connected to' | wc -l) -ge "1" ]; do
	echo "not successful, trying again"
	sleep 1
done
echo "Successfully connected to Skycontroller 2!"
echo "Remounting filesystem as read/write"
/tmp/*4g/*/uavpal/bin/adb shell "mount -o remount,rw /" 2>/dev/null
echo "Removing init script for softmod"
/tmp/*4g/*/uavpal/bin/adb shell "rm -f /etc/boxinit.d/99-uavpal.rc" 2>/dev/null
echo "Remounting filesystem as read-only"
/tmp/*4g/*/uavpal/bin/adb shell "mount -o remount,ro /" 2>/dev/null
echo "Removing zerotier-one data"
/tmp/*4g/*/uavpal/bin/adb shell "rm -rf /data/lib/zerotier-one" 2>/dev/null
echo "Removing uavpal softmod files"
/tmp/*4g/*/uavpal/bin/adb shell "rm -rf /data/lib/ftp/uavpal" 2>/dev/null
echo "All done! :)"
echo
