#!/bin/sh
echo "=== Installing Disco4G on Skycontroller 2 ==="
ip_sc2=`netstat -nu |grep 9988 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
until /data/ftp/uavpal/bin/adb connect ${ip_sc2}:9050 2>/dev/null;
do
	echo "Trying to connect from Disco to Skycontroller 2 via Wi-Fi"
done
echo "Copying softmod files from Disco to Skycontroller 2"
/data/ftp/uavpal/bin/adb push /tmp/disco4g/skycontroller2/uavpal /data/lib/ftp/uavpal/ 2>/dev/null
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
/data/ftp/uavpal/bin/adb shell "ln -s /data/lib/ftp/uavpal/conf/local.conf /data/lib/zerotier-one/local.conf  2>&1 |grep -v 'File exists'" 2>/dev/null
echo "All done! :)"
echo
