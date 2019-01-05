#!/bin/sh
echo "=== Uninstalling UAVPAL softmod on Disco ==="
echo "Remounting filesystem as read/write"
mount -o remount,rw /
echo "Removing ppp directory including symlink for ppp-lte settings"
rm -rf /etc/ppp
echo "Removing symlink udev rule"
rm -f /lib/udev/rules.d/70-huawei-e3372.rules
echo "Removing symlink for ntpd's config file"
rm -f /etc/ntp.conf
echo "Remounting filesystem as read-only"
mount -o remount,ro /
echo "Removing zerotier-one data"
rm -rf /data/lib/zerotier-one
echo "Removing uavpal softmod files"
rm -rf /data/ftp/uavpal
echo "Removing uavpal softmod installation files"
rm -rf /data/ftp/disco4g*
echo "All done! :)"
echo
