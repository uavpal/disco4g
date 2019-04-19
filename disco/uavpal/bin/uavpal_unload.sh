#!/bin/sh

usbmodeswitchStatus=`ps |grep usb_modeswitch |grep -v grep |wc -l`
if [ $usbmodeswitchStatus -ne 0 ]; then
	exit 0  # ignoring "removal" event while usb_modesswitch is running
fi

ulogger -s -t uavpal_drone "Huawei USB device disconnected"
ulogger -s -t uavpal_drone "... unloading scripts and daemons"
killall -9 uavpal_disco.sh
killall -9 uavpal_bebop2.sh
killall -9 uavpal_glympse.sh
killall -9 zerotier-one
killall -9 ntpd
killall -9 udhcpc
killall -9 curl
killall -9 chat
killall -9 pppd

ulogger -s -t uavpal_drone "... clearing iptables rules"
iptables -F INPUT

ulogger -s -t uavpal_drone "... clearing default route"
ip route del default via $(cat /tmp/hilink_router_ip)

ulogger -s -t uavpal_drone "... removing temp files"
rm /tmp/serial_ctrl_dev
rm /tmp/hilink_router_ip

ulogger -s -t uavpal_drone "... removing lock files"
rm /tmp/lock/uavpal_disco
rm /tmp/lock/uavpal_bebop2
rm /tmp/lock/uavpal_unload
rm /tmp/lock/uavpal_sdcard_remove

ulogger -s -t uavpal_drone "... unloading kernel modules"
rmmod xt_tcpudp
rmmod iptable_filter
rmmod ip_tables
rmmod x_tables
rmmod option
rmmod usb_wwan
rmmod usbserial
rmmod tun
rmmod bsd_comp.ko
rmmod ppp_deflate.ko
rmmod ppp_async.ko
rmmod ppp_generic.ko
rmmod slhc.ko
rmmod crc-ccitt

ulogger -s -t uavpal_drone "*** idle on Wi-Fi ***"