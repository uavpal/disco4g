#!/bin/sh
{

# variables
initial_connection_timeout_seconds=20

ulogger -s -t uavpal_drone "Huawei USB device detected (USB ID: $(lsusb |grep 12d1 |head -n 1 | cut -d ' ' -f 6))"
ulogger -s -t uavpal_drone "=== Loading uavpal softmod $(head -1 /data/ftp/uavpal/version.txt |tr -d '\r\n' |tr -d '\n') ==="
	
# set platform, evinrude=Disco, ardrone3=Bebop 2
platform=$(grep 'ro.parrot.build.product' /etc/build.prop | cut -d'=' -f 2)
drone_fw_version=$(grep 'ro.parrot.build.uid' /etc/build.prop | cut -d '-' -f 3)
drone_fw_version_numeric=${drone_fw_version//.}

if [ "$platform" == "evinrude" ]; then
	drone_alias="Parrot Disco"
	ncm_usb_if="usb0"
	if [ "$drone_fw_version_numeric" -ge "170" ]; then
		kernel_mods="1.7.0"
	else
		kernel_mods="1.4.1"
	fi
elif [ "$platform" == "ardrone3" ]; then
	drone_alias="Parrot Bebop 2"
	ncm_usb_if="usb"
	kernel_mods="4.4.2"
else
	ulogger -s -t uavpal_drone "... current platform ${platform} is not supported by the softmod - exiting!"
	exit 1
fi

ulogger -s -t uavpal_drone "... detected ${drone_alias} (platform ${platform}), firmware version ${drone_fw_version}"
ulogger -s -t uavpal_drone "... trying to use kernel modules compiled for firmware ${kernel_mods}"

ulogger -s -t uavpal_drone "... loading tunnel kernel module (for zerotier)"
insmod /data/ftp/uavpal/mod/${kernel_mods}/tun.ko

ulogger -s -t uavpal_drone "... loading USB modem kernel modules"
insmod /data/ftp/uavpal/mod/${kernel_mods}/usbserial.ko                 # needed for Disco only
insmod /data/ftp/uavpal/mod/${kernel_mods}/usb_wwan.ko
insmod /data/ftp/uavpal/mod/${kernel_mods}/option.ko

ulogger -s -t uavpal_drone "... loading iptables kernel modules (required for security)"
insmod /data/ftp/uavpal/mod/${kernel_mods}/x_tables.ko                  # needed for Disco firmware <=1.4.1 only
insmod /data/ftp/uavpal/mod/${kernel_mods}/ip_tables.ko                 # needed for Disco firmware <=1.4.1 only
insmod /data/ftp/uavpal/mod/${kernel_mods}/iptable_filter.ko            # needed for Disco firmware <=1.4.1 and >=1.7.0 and Bebop 2 firmware >= 4.4.2
insmod /data/ftp/uavpal/mod/${kernel_mods}/xt_tcpudp.ko                 # needed for Disco firmware <=1.4.1 only

# Security: block incoming connections on the Internet interface
# these connections should only be allowed on Wi-Fi (eth0) and via zerotier (zt*)
ulogger -s -t uavpal_drone "... applying iptables security rules"
ip_block='21 23 51 61 873 8888 9050 44444 67 5353 14551'
for i in $ip_block; do iptables -I INPUT -p tcp -i ${ncm_usb_if} --dport $i -j DROP; done

ulogger -s -t uavpal_drone "... running usb_modeswitch to switch Huawei modem into ncm mode"
/data/ftp/uavpal/bin/usb_modeswitch -v 12d1 -p `lsusb |grep "ID 12d1" | cut -f 3 -d \:` --huawei-alt-mode -s 3

until [ -d "/proc/sys/net/ipv4/conf/${ncm_usb_if}" ] && [ -c "/dev/ttyUSB0" ]; do usleep 100000; done
ulogger -s -t uavpal_drone "... detected Huawei USB modem in ncm mode (USB ID: $(lsusb |grep 12d1 |head -n 1 | cut -d ' ' -f 6))"

ulogger -s -t uavpal_drone "... starting connection manager script"
/data/ftp/uavpal/bin/uavpal_connmgr.sh ${ncm_usb_if} &

ulogger -s -t uavpal_drone "... waiting for public Internet connection"
while true; do
	if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
		ulogger -s -t uavpal_drone "... public Internet connection is up"
		break # break out of loop
	fi
done

ulogger -s -t uavpal_drone "... setting date/time using ntp"
ntpd -n -d -q -p 0.debian.pool.ntp.org -p 1.debian.pool.ntp.org -p 2.debian.pool.ntp.org -p 3.debian.pool.ntp.org

ulogger -s -t uavpal_drone "... starting glympse script for GPS tracking"
/data/ftp/uavpal/bin/uavpal_glympse.sh &

if [ -d "/data/lib/zerotier-one/networks.d" ] && [ ! -f "/data/lib/zerotier-one/networks.d/$(head -1 /data/ftp/uavpal/conf/zt_networkid |tr -d '\r\n' |tr -d '\n').conf" ]; then
	ulogger -s -t uavpal_drone "... zerotier config's network ID does not match zt_networkid config - removing zerotier data directory to allow join of new network ID"
	rm -rf /data/lib/zerotier-one 2>/dev/null
fi

ulogger -s -t uavpal_drone "... starting zerotier daemon"
/data/ftp/uavpal/bin/zerotier-one -d

if [ ! -d "/data/lib/zerotier-one/networks.d" ]; then
	ulogger -s -t uavpal_drone "... (initial-)joining zerotier network ID"
	while true
	do
		ztjoin_response=`/data/ftp/uavpal/bin/zerotier-one -q join $(head -1 /data/ftp/uavpal/conf/zt_networkid |tr -d '\r\n' |tr -d '\n')`
		if [ "`echo $ztjoin_response |head -n1 |awk '{print $1}')`" == "200" ]; then
			ulogger -s -t uavpal_drone "... successfully joined zerotier network ID"
			break # break out of loop
		else
			ulogger -s -t uavpal_drone "... ERROR joining zerotier network ID: $ztjoin_response - trying again"
			sleep 1
		fi
	done
fi
ulogger -s -t uavpal_drone "*** idle on LTE ***"
} &
