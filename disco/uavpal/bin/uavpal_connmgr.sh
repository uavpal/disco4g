#!/bin/sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

# variables
connection_setup_timeout_seconds=20
ping_retries_per_destination=2
first_run="true"
ping_destinations="8.8.8.8 192.5.5.241 199.7.83.42" # google-public-dns-a.google.com, f.root-servers.org, l.root-servers.org

connect()
{
	ulogger -s -t uavpal_connmgr "... establishing connection to mobile network"
	echo -ne "AT+CGDCONT=1,\"IP\",\"`head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n'`\"\r\n" > /dev/ttyUSB2
	echo -ne "AT^NDISDUP=1,1,\"`head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n'`\"\r\n" > /dev/ttyUSB2
	# querying DHCP information
	for p in `seq 1 $connection_setup_timeout_seconds`; do
		pdpParameters=`(/data/ftp/uavpal/bin/chat -V -t 1 '' 'AT+CGCONTRDP' 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2) 2>&1 |grep "CGCONTRDP:" |tail -n 1`
		if [ ! -z "$pdpParameters" ]; then
			ulogger -s -t uavpal_connmgr "... setting IP, default gateway and DNS"
			ifconfig $1 $(echo "${pdpParameters//\"}" | cut -d',' -f4 | awk -F'.' '{print $1"."$2"."$3"."$4}')
			ifconfig $1 netmask $(echo "${pdpParameters//\"}" | cut -d',' -f4 | awk -F'.' '{print $5"."$6"."$7"."$8}')
			ip route del default
			ip route add default via $(echo "${pdpParameters//\"}" | cut -d',' -f5) dev $1
			echo nameserver $(echo "${pdpParameters//\"}" | cut -d',' -f6) >/etc/resolv.conf
			echo nameserver $(echo "${pdpParameters//\"}" | cut -d',' -f7) >>/etc/resolv.conf
			break # break out of loop
		elif [ $p == $connection_setup_timeout_seconds ]; then
			ulogger -s -t uavpal_connmgr "... no IP address received while trying to establishing connection, disconnecting now"
			echo -ne "AT^NDISDUP=1,0\r\n" > /dev/ttyUSB2
		fi
		sleep 1
	done
}

check_connection()
{
	for check in $ping_destinations; do
		for i in $(seq 1 $ping_retries_per_destination); do
			ping -W 5 -c 1 $check >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				return 0
			fi
			sleep 1
		done
	done
	# none of the ping destinations could have been reached
	return 1
}

stty -echo -F /dev/ttyUSB2
while true; do
	if [ "$first_run" == "true" ]; then
		connect "$1"
		first_run="false"
	else
		check_connection
		if [ $? -ne 0 ]; then
			ulogger -s -t uavpal_connmgr "... modem disconnected, trying to reconnect"
			echo -ne "AT^NDISDUP=1,0\r\n" > /dev/ttyUSB2
			sleep 1
			connect "$1"
		fi
	fi
	sleep 5
done