#!/bin/sh
echo "=== Installing UAVPAL softmod on Skycontroller 2 ==="
until [ "$ip_sc2" != "" ]; do
	ip_sc2=`netstat -nu |grep 9988 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
	echo "Trying to detect Skycontroller 2 (ensure Skycontroller 2 is turned on and its power LED is green)"
	sleep 1
done

/data/ftp/uavpal/bin/adb start-server 2>/dev/null

echo "Trying to connect to Skycontroller 2 ($ip_sc2) via adb"
until [ $(/data/ftp/uavpal/bin/adb connect ${ip_sc2}:9050 2>/dev/null | grep 'connected to' | wc -l) -ge "1" ]; do
	echo "not successful, trying again"
	sleep 1
done
echo "Successfully connected to Skycontroller 2!"
echo "Copying softmod files from drone to Skycontroller 2"
until /data/ftp/uavpal/bin/adb push /tmp/*4g/skycontroller2/uavpal /data/lib/ftp/uavpal/ 2>/dev/null; do echo "Error while copying files to Skycontroller 2, trying again"; done
echo "Making binaries and scripts executable"
/data/ftp/uavpal/bin/adb shell "chmod +x /data/lib/ftp/uavpal/bin/*" 2> /dev/null
echo "Remounting filesystem as read/write"
/data/ftp/uavpal/bin/adb shell "mount -o remount,rw /" 2>/dev/null
echo "Creating init script for softmod"
/data/ftp/uavpal/bin/adb shell "cat << '' > /etc/boxinit.d/99-uavpal.rc
service uavpal /data/lib/ftp/uavpal/bin/uavpal_sc2.sh
    class main
    user root
" 2>/dev/null
echo "Setting file permissions for init script"
/data/ftp/uavpal/bin/adb shell "chmod 640 /etc/boxinit.d/99-uavpal.rc" 2>/dev/null
echo "Remounting filesystem as read-only"
/data/ftp/uavpal/bin/adb shell "mount -o remount,ro /" 2>/dev/null
echo "Creating zerotier-one directory"
/data/ftp/uavpal/bin/adb shell "mkdir -p /data/lib/zerotier-one" 2>/dev/null
echo "Creating symlink for zerotier-one's local config file"
/data/ftp/uavpal/bin/adb shell "ln -s /data/lib/ftp/uavpal/conf/local.conf /data/lib/zerotier-one/local.conf 2>&1 |grep -v 'File exists'" 2>/dev/null
echo "All done! :)"
echo
