#!/bin/sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

# variables
connection_setup_timeout_seconds=20
ping_retries_per_destination=2
first_run="true"
ping_destinations="8.8.8.8 192.5.5.241 199.7.83.42" # google-public-dns-a.google.com, f.root-servers.org, l.root-servers.org

connect()
{
	ulogger -s -t uavpal_connmgr "... establishing connection to mobile network using APN \"$(head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n')\""
	/data/ftp/uavpal/bin/chat -V -t 1 '' "AT+CGDCONT=1,\"IP\",\"$(head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n')\"" 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2 2>&1
	/data/ftp/uavpal/bin/chat -V -t 1 '' "AT\^NDISDUP=1,1,\"$(head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n')\"" 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2 2>&1
	# querying DHCP information
	for p in `seq 1 $connection_setup_timeout_seconds`; do
		pdpParameters=`(/data/ftp/uavpal/bin/chat -V -t 1 '' 'AT+CGCONTRDP' 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2) 2>&1 |grep "CGCONTRDP:" |tail -n 1`
		if [ ! -z "$pdpParameters" ]; then
			ip=$(echo "${pdpParameters//\"}" | cut -d',' -f4 | awk -F'.' '{print $1"."$2"."$3"."$4}')
			netmask=$(echo "${pdpParameters//\"}" | cut -d',' -f4 | awk -F'.' '{print $5"."$6"."$7"."$8}')
			gateway=$(echo "${pdpParameters//\"}" | cut -d',' -f5)
			dns1=$(echo "${pdpParameters//\"}" | cut -d',' -f6)
			dns2=$(echo "${pdpParameters//\"}" | cut -d',' -f7)
			ulogger -s -t uavpal_connmgr "... setting IP ($ip), netmask ($netmask), default gateway ($gateway) and DNS (${dns1}$(if [ "$dns2" != "" ]; then echo ", $dns2"; fi))"
			ifconfig $1 $ip netmask $netmask
			ip route del default
			ip route add default via $gateway dev $1
			echo nameserver $dns1 >/etc/resolv.conf
			if [ "$dns2" != "" ]; then echo nameserver $dns2 >>/etc/resolv.conf; fi
			break # break out of loop
		elif [ $p == $connection_setup_timeout_seconds ]; then
			ulogger -s -t uavpal_connmgr "... no IP address received while trying to establishing connection, disconnecting now"
			/data/ftp/uavpal/bin/chat -V -t 1 '' 'AT\^NDISDUP=1,0' 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2 2>&1
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
			/data/ftp/uavpal/bin/chat -V -t 1 '' 'AT\^NDISDUP=1,0' 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2 2>&1
			sleep 1
			connect "$1"
		fi
	fi
	sleep 5
done