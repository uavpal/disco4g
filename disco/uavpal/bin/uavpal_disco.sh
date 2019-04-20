#!/bin/sh
{
# exports
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

# variables
cdc_if="eth1"
# TODO: make the following dynamic if possible
ppp_if="ppp0"
# TODO: make the following two dynamic (e.g. via AT^NDISDUP=1,0)
serial_ctrl_dev="ttyUSB0"
serial_ppp_dev="ttyUSB1"

# functions
. /data/ftp/uavpal/bin/uavpal_globalfunctions.sh

# main
ulogger -s -t uavpal_drone "Huawei USB device detected (USB ID: $(lsusb |grep 12d1 |head -n 1 | cut -d ' ' -f 6))"
ulogger -s -t uavpal_drone "=== Loading uavpal softmod $(head -1 /data/ftp/uavpal/version.txt |tr -d '\r\n' |tr -d '\n') ==="

# set platform, evinrude=Disco, ardrone3=Bebop 2
platform=$(grep 'ro.parrot.build.product' /etc/build.prop | cut -d'=' -f 2)
drone_fw_version=$(grep 'ro.parrot.build.uid' /etc/build.prop | cut -d '-' -f 3)
drone_fw_version_numeric=${drone_fw_version//.}

if [ "$platform" == "evinrude" ]; then
	drone_alias="Parrot Disco"
	if [ "$drone_fw_version_numeric" -ge "170" ]; then
		kernel_mods="1.7.0"
	else
		kernel_mods="1.4.1"
	fi
elif [ "$platform" == "ardrone3" ]; then
	drone_alias="Parrot Bebop 2"
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

ulogger -s -t uavpal_drone "... running usb_modeswitch to switch Huawei modem into huawei-new-mode"
/data/ftp/uavpal/bin/usb_modeswitch -v 12d1 -p `lsusb |grep "ID 12d1" | cut -f 3 -d \:` --huawei-new-mode -s 3

ulogger -s -t uavpal_drone "... detecting Huawei modem type"
while true
do
	# -=-=-=-=-= Hi-Link mode =-=-=-=-=-
	if [ -d "/proc/sys/net/ipv4/conf/${cdc_if}" ]; then
		ulogger -s -t uavpal_drone "... detected Huawei USB modem in Hi-Link mode"
		ulogger -s -t uavpal_drone "... unloading Stick Mode kernel modules (not required for Hi-Link firmware)"
		rmmod option
		rmmod usb_wwan
		rmmod usbserial
		ulogger -s -t uavpal_drone "... connecting modem to Internet (Hi-Link)"
		connect_hilink
		ulogger -s -t uavpal_drone "... enabling Hi-Link DMZ mode (1:1 NAT for better zerotier performance)"
		hilink_api "post" "/api/security/dmz" "<request><DmzStatus>1</DmzStatus><DmzIPAddress>${hilink_ip}</DmzIPAddress></request>"
		ulogger -s -t uavpal_drone "... setting Hi-Link NAT type full cone (better zerotier performance)"
		hilink_api "post" "/api/security/nat" "<request><NATType>1</NATType></request>"
		ulogger -s -t uavpal_drone "... querying Huawei device details via Hi-Link API"
		hilink_dev_info=$(hilink_api "get" "/api/device/information")
		ulogger -s -t uavpal_drone "... model: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//DeviceName)' -), hardware version: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//HardwareVersion)' -)"
		ulogger -s -t uavpal_drone "... software version: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//SoftwareVersion)' -), WebUI version: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//WebUIVersion)' -)"
		firewall ${cdc_if}
		ulogger -s -t uavpal_drone "... starting connection keep-alive handler in background"
		connection_handler_hilink &
		break 1 # break out of while loop
		
	fi
	# -=-=-=-=-= Stick mode =-=-=-=-=-
	if [ -c "/dev/${serial_ctrl_dev}" ]; then
		ulogger -s -t uavpal_drone "... detected Huawei USB modem in Stick mode"
		ulogger -s -t uavpal_drone "... loading ppp kernel modules"
		insmod /data/ftp/uavpal/mod/${kernel_mods}/crc-ccitt.ko
		insmod /data/ftp/uavpal/mod/${kernel_mods}/slhc.ko
		insmod /data/ftp/uavpal/mod/${kernel_mods}/ppp_generic.ko
		insmod /data/ftp/uavpal/mod/${kernel_mods}/ppp_async.ko
		insmod /data/ftp/uavpal/mod/${kernel_mods}/ppp_deflate.ko
		insmod /data/ftp/uavpal/mod/${kernel_mods}/bsd_comp.ko
		ulogger -s -t uavpal_drone "... connecting modem to Internet (ppp)"
		connect_stick
		ulogger -s -t uavpal_drone "... querying Huawei device details via AT command"
		fhverString=$(at_command "AT\^FHVER" "OK" "1" | grep "FHVER:" | tail -n 1)
		ulogger -s -t uavpal_drone "... model: $(echo "$fhverString" | cut -d " " -f 1 | cut -d "\"" -f 2), hardware version: $(echo "$fhverString" | cut -d "," -f 2 | cut -d "\"" -f 1)"
		ulogger -s -t uavpal_drone "... software version: $(echo "$fhverString" | cut -d " " -f 2 | cut -d "," -f 1)"
		firewall ${ppp_if}
		ulogger -s -t uavpal_drone "... starting connection keep-alive handler in background"
		connection_handler_stick &
		break 1 # break out of while loop
	fi
	usleep 100000
done

while true; do
	check_connection
	if [ $? -eq 0 ]; then
		break # break out of loop
	fi
done
ulogger -s -t uavpal_drone "... public Internet connection is up"

ulogger -s -t uavpal_drone "... setting DNS servers statically (Google Public DNS)"
echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4' >/etc/resolv.conf

ulogger -s -t uavpal_drone "... setting date/time using ntp"
ntpd -n -d -q -p 0.debian.pool.ntp.org -p 1.debian.pool.ntp.org -p 2.debian.pool.ntp.org -p 3.debian.pool.ntp.org

if [ -f /data/ftp/uavpal/conf/debug ]; then
	debug_filename="/data/ftp/internal_000/Debug/ulog_debug_$(date +%Y%m%d%H%M%S).log"
	ulogger -s -t uavpal_drone "... Debug mode is enabled - writing debug log to internal storage: $debug_filename"
	kill -9 $(ps |grep ulogcat |grep debugdummy |cut -f 1 -d " ")
	ulogcat -u -k -l -F debugdummy >$debug_filename &
fi

ulogger -s -t uavpal_drone "... starting Glympse script for GPS tracking"
/data/ftp/uavpal/bin/uavpal_glympse.sh &

if [ -d "/data/lib/zerotier-one/networks.d" ] && [ ! -f "/data/lib/zerotier-one/networks.d/$(conf_read zt_networkid).conf" ]; then
	ulogger -s -t uavpal_drone "... zerotier config's network ID does not match zt_networkid config - removing zerotier data directory to allow join of new network ID"
	rm -rf /data/lib/zerotier-one 2>/dev/null
	mkdir -p /data/lib/zerotier-one
	ln -s /data/ftp/uavpal/conf/local.conf /data/lib/zerotier-one/local.conf
fi

ulogger -s -t uavpal_drone "... starting zerotier daemon"
/data/ftp/uavpal/bin/zerotier-one -d

if [ ! -d "/data/lib/zerotier-one/networks.d" ]; then
	ulogger -s -t uavpal_drone "... (initial-)joining zerotier network ID $(conf_read zt_networkid)"
	while true
	do
		ztjoin_response=`/data/ftp/uavpal/bin/zerotier-one -q join $(conf_read zt_networkid)`
		if [ "`echo $ztjoin_response |head -n1 |awk '{print $1}')`" == "200" ]; then
			ulogger -s -t uavpal_drone "... successfully joined zerotier network ID $(conf_read zt_networkid)"
			break # break out of loop
		else
			ulogger -s -t uavpal_drone "... ERROR joining zerotier network ID $(conf_read zt_networkid): $ztjoin_response - trying again"
			sleep 1
		fi
	done
fi
ulogger -s -t uavpal_drone "*** idle on LTE ***"
} &
