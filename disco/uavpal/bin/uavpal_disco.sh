#!/bin/sh
ulogger -s -t uavpal_disco "Huawei USB device detected"
ulogger -s -t uavpal_disco "=== Enabling LTE ==="

ulogger -s -t uavpal_disco "... loading tunnel kernel module (for zerotier)"
insmod /data/ftp/uavpal/mod/tun.ko

ulogger -s -t uavpal_disco "... loading E3372s kernel modules (required for detection)"
insmod /data/ftp/uavpal/mod/usbserial.ko 
insmod /data/ftp/uavpal/mod/usb_wwan.ko
insmod /data/ftp/uavpal/mod/option.ko

ulogger -s -t uavpal_disco "... loading iptables kernel modules (required for security)"
insmod /data/ftp/uavpal/mod/x_tables.ko
insmod /data/ftp/uavpal/mod/ip_tables.ko
insmod /data/ftp/uavpal/mod/iptable_filter.ko
insmod /data/ftp/uavpal/mod/xt_tcpudp.ko

# Security: block incoming connections on the Internet interfaces (ppp* for E3372s and eth1 for E3372h)
# these connections should only be allowed on Wi-Fi (eth0) and via zerotier (zt*)
ulogger -s -t uavpal_disco "... applying iptables security rules"
if_block='ppp+ eth1'
for i in $if_block
do
	iptables -I INPUT -p tcp -i eth1 --dport 21 -j DROP      # inetd (ftp:/data/ftp)
	iptables -I INPUT -p tcp -i eth1 --dport 23 -j DROP      # telnet
	iptables -I INPUT -p tcp -i eth1 --dport 51 -j DROP      # inetd (ftp:/update)
	iptables -I INPUT -p tcp -i eth1 --dport 61 -j DROP      # inetd (ftp:/data/ftp/internal_000/flightplans)
	iptables -I INPUT -p tcp -i eth1 --dport 873 -j DROP     # rsync
	iptables -I INPUT -p tcp -i eth1 --dport 8888 -j DROP    # dragon-prog
	iptables -I INPUT -p tcp -i eth1 --dport 9050 -j DROP    # adb
	iptables -I INPUT -p tcp -i eth1 --dport 44444 -j DROP   # dragon-prog
	iptables -I INPUT -p udp -i eth1 --dport 67 -j DROP      # dnsmasq
	iptables -I INPUT -p udp -i eth1 --dport 5353 -j DROP    # avahi-daemon
	iptables -I INPUT -p udp -i eth1 --dport 14551 -j DROP   # dragon-prog
done

ulogger -s -t uavpal_disco "... running usb_modeswitch"
/data/ftp/uavpal/bin/usb_modeswitch -J -v 12d1 -p `lsusb |grep "ID 12d1" | cut -f 3 -d \:`

ulogger -s -t uavpal_disco "... trying to detect 4G USB modem"
while true
do
	# -=-=-=-=-= Hi-Link Mode =-=-=-=-=-
	if [ -d "/proc/sys/net/ipv4/conf/eth1" ]; then
		huawei_mode="hilink"
		ulogger -s -t uavpal_disco "... detected Huawei USB modem in Hi-Link mode"
		ulogger -s -t uavpal_disco "... unloading E3372s kernel modules (not required as Hi-Link was detected)"
		rmmod option
		rmmod usb_wwan
		rmmod usbserial
		ulogger -s -t uavpal_disco "... setting IP and route"
		ifconfig eth1 192.168.8.100 netmask 255.255.255.0
		ip route add default via 192.168.8.1 dev eth1
		ulogger -s -t uavpal_disco "... enabling Hi-Link DMZ mode (1:1 NAT for better zerotier performance)"
		export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib
		sessionInfo=`/data/ftp/uavpal/bin/curl -s -X GET "http://192.168.8.1/api/webserver/SesTokInfo"`
		cookie=`echo "$sessionInfo" | grep "SessionID=" | cut -b 10-147`
		token=`echo "$sessionInfo" | grep "TokInfo" | cut -b 10-41`
		/data/ftp/uavpal/bin/curl -s -X POST "http://192.168.8.1/api/security/dmz" -d "<request><DmzStatus>1</DmzStatus><DmzIPAddress>192.168.8.100</DmzIPAddress></request>" -H "Cookie: $cookie" -H "__RequestVerificationToken: $token"
		break 1 # break out of while loop
	fi

	# -=-=-=-=-= Stick Mode =-=-=-=-=-
	if [ -c "/dev/ttyUSB0" ]; then
		huawei_mode="stick"
		ulogger -s -t uavpal_disco "... detected Huawei USB modem in Stick mode"
		ulogger -s -t uavpal_disco "... loading ppp kernel modules"
		insmod /data/ftp/uavpal/mod/crc-ccitt.ko
		insmod /data/ftp/uavpal/mod/slhc.ko
		insmod /data/ftp/uavpal/mod/ppp_generic.ko
		insmod /data/ftp/uavpal/mod/ppp_async.ko
		insmod /data/ftp/uavpal/mod/ppp_deflate.ko
		insmod /data/ftp/uavpal/mod/bsd_comp.ko
		ulogger -s -t uavpal_disco "... running pppd to connect to LTE network"
		LD_PRELOAD=/data/ftp/uavpal/lib/libpam.so.0:/data/ftp/uavpal/lib/libpcap.so.0.8:/data/ftp/uavpal/lib/libaudit.so.1 /data/ftp/uavpal/bin/pppd call lte
		break 1 # break out of while loop
	fi
	sleep 1
done

ulogger -s -t uavpal_disco "... setting DNS servers statically (to Google)"
echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4' >/etc/resolv.conf

ulogger -s -t uavpal_disco "... waiting for Internet connection"
while true; do
	if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
		ulogger -s -t uavpal_disco "... Internet connection is up"
		break # break out of loop
	fi
done

ulogger -s -t uavpal_disco "... setting date/time using ntp"
ntpd -n -d -q

ulogger -s -t uavpal_disco "... starting glympse script for GPS tracking"
/data/ftp/uavpal/bin/uavpal_glympse.sh $huawei_mode &

ulogger -s -t uavpal_disco "... starting zerotier daemon"
/data/ftp/uavpal/bin/zerotier-one -d

if [ ! -d "/data/lib/zerotier-one/networks.d" ]; then
	ulogger -s -t uavpal_disco "... (initial-)joining zerotier network ID"
	while true
	do
		ztjoin_response=`/data/ftp/uavpal/bin/zerotier-one -q join $(head -1 /data/ftp/uavpal/conf/zt_networkid |tr -d '\r\n' |tr -d '\n')`
		if [ "`echo $ztjoin_response |head -n1 |awk '{print $1}')`" == "200" ]; then
			ulogger -s -t uavpal_disco "... successfully joined zerotier network ID"
			break # break out of loop
		else
			ulogger -s -t uavpal_disco "... ERROR joining zerotier network ID: $ztjoin_response - trying again"
			sleep 1
		fi
	done
fi

ulogger -s -t uavpal_disco "... looping to keep script alive. ugly, yes!"
ulogger -s -t uavpal_disco "*** idle on LTE ***"
while true; do sleep 10; done
