#!/bin/sh
echo "=== Fixing Disco4G after you update the firmware; re-creates the needed symlinks ==="
mount -o remount,rw /
mkdir -p /etc/ppp/peers
ln -s /data/ftp/uavpal/conf/lte /etc/ppp/peers/lte
ln -s /data/ftp/uavpal/conf/70-huawei-e3372.rules /lib/udev/rules.d/70-huawei-e3372.rules
ln -s /data/ftp/uavpal/conf/ntp.conf /etc/ntp.conf
echo "Done, reboot the Disco to continue"
