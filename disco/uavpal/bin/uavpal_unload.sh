#!/bin/sh

usbmodeswitchStatus=`ps |grep usb_modeswitch |grep -v grep |wc -l`
if [ $usbmodeswitchStatus -ne 0 ]; then
	exit 0  # ignoring "removal" event while usb_modesswitch is running
fi

ulogger -s -t uavpal_disco "Huawei USB device disconnected"
ulogger -s -t uavpal_disco "... unloading scripts and daemons"
killall -9 uavpal_disco.sh
killall -9 uavpal_hilink.sh
killall -9 uavpal_glympse.sh
killall -9 zerotier-one
killall -9 udhcpc
killall -9 curl
killall -9 chat
killall -9 pppd

ulogger -s -t uavpal_bebop2 "... removing lock files"
rm /tmp/lock/uavpal_disco
rm /tmp/lock/uavpal_unload

ulogger -s -t uavpal_disco "... unloading kernel modules"
rmmod bsd_comp
rmmod ppp_deflate
rmmod ppp_async
rmmod ppp_generic
rmmod slhc
rmmod crc-ccitt
#rmmod xt_tcpudp
#rmmod iptable_filter
#rmmod ip_tables
#rmmod x_tables
rmmod option
rmmod usb_wwan
rmmod usbserial
rmmod tun

ulogger -s -t uavpal_disco "*** idle on Wi-Fi ***"