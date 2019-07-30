#!/bin/sh

nodemcu_ip="`head -1 /data/ftp/uavpal/conf/nodemcu_ip |tr -d '\r\n' |tr -d '\n'`"

while true; do
	while true; do
		echo "!"
		usleep 300000
	done | /data/ftp/uavpal/bin/netcat-arm -u ${nodemcu_ip} 8888
done

