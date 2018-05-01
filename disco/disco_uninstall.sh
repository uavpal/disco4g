#!/bin/sh
echo "=== Uninstalling Disco4G on Disco ==="
echo "Remounting filesystem as read/write"
mount -o remount,rw /
echo "Removing symlink for ppp-lte settings"
rm -f /etc/ppp/peers/lte
echo "Removing symlink udev rule"
rm -f /lib/udev/rules.d/70-huawei-e3372.rules
echo "Removing symlink for ntpd's config file"
rm -f /etc/ntp.conf
echo "Remounting filesystem as read-only"
mount -o remount,ro /
echo "Removing zerotier-one data"
rm -rf /data/lib/zerotier-one
echo "Removing uavpal softmod filesCreating symlink for zerotier-one's local config file"
rm -rf /data/ftp/uavpal
echo "All done! :)"
echo
