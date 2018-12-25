#!/bin/sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

# variables
connection_setup_timeout_seconds=20
first_run="true"

stty -echo -F /dev/ttyUSB2

while true; do
	# querying NDIS/WWAN connection status from modem
	connString=`(/data/ftp/uavpal/bin/chat -V -t 1 '' 'AT\^NDISSTATQRY?' 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2) 2>&1 |grep "NDISSTATQRY:" |tail -n 1`
	if [ $(echo $connString | cut -d' ' -f2 | cut -d',' -f1) == 0 ]; then
		if [ "$first_run" == "false" ]; then
			ulogger -s -t uavpal_connmgr "... modem disconnected, trying to reconnect"
		else
			first_run="false"
		fi
		ulogger -s -t uavpal_connmgr "... establishing connection to mobile network"
		echo -ne "AT+CGDCONT=1,\"IP\",\"`head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n'`\"\r\n" > /dev/ttyUSB2
		echo -ne "AT^NDISDUP=1,1,\"`head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n'`\"\r\n" > /dev/ttyUSB2
		# querying DHCP information
		for p in `seq 1 $connection_setup_timeout_seconds`;	do
			pdpParameters=`(/data/ftp/uavpal/bin/chat -V -t 1 '' 'AT+CGCONTRDP' 'OK' '' > /dev/ttyUSB2 < /dev/ttyUSB2) 2>&1 |grep "CGCONTRDP:" |tail -n 1`
			if [ ! -z "$pdpParameters" ]; then
					ulogger -s -t uavpal_connmgr "... setting IP, default gateway and DNS"
					ifconfig usb0 $(echo "${pdpParameters//\"}" | cut -d',' -f4 | awk -F'.' '{print $1"."$2"."$3"."$4}')
					ifconfig usb0 netmask $(echo "${pdpParameters//\"}" | cut -d',' -f4 | awk -F'.' '{print $5"."$6"."$7"."$8}')
					ip route del default
					ip route add default via $(echo "${pdpParameters//\"}" | cut -d',' -f5) dev usb0
					echo nameserver $(echo "${pdpParameters//\"}" | cut -d',' -f6) >/etc/resolv.conf
					echo nameserver $(echo "${pdpParameters//\"}" | cut -d',' -f7) >>/etc/resolv.conf
				break # break out of loop
			elif [ $p == $connection_setup_timeout_seconds ]; then
				ulogger -s -t uavpal_connmgr "... no IP address received while trying to establishing connection, disconnecting now"
				echo -ne "AT^NDISDUP=1,0\r\n" > /dev/ttyUSB2
			fi
			sleep 1
		done
	else
		sleep 5
	fi
done
