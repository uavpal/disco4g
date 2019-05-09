#!/bin/sh

nodemcu_ip="192.168.42.25"

while true; do
	while true; do
		echo "!"
		usleep 300000
	done | /data/ftp/uavpal/bin/netcat-arm -u ${nodemcu_ip} 8888
done

