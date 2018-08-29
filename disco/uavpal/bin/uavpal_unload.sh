#!/bin/sh
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

ulogger -s -t uavpal_disco "... removing lock file"
rm /tmp/lock/uavpal_disco

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