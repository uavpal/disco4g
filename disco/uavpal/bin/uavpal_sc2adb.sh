#!/bin/sh
until [ "$ip_sc2" != "" ]; do
	ip_sc2=`netstat -nu |grep 9988 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
	echo "Trying to detect Skycontroller 2 (ensure Skycontroller 2 is turned on and its power LED is green)"
	sleep 1
done

/data/ftp/uavpal/bin/adb start-server 2>/dev/null

echo "Trying to connect to Skycontroller 2 ($ip_sc2) via adb"
until [ $(/data/ftp/uavpal/bin/adb connect ${ip_sc2}:9050 2>/dev/null | grep 'connected to' | wc -l) -ge "1" ]; do
	echo "not successful, trying again"
	sleep 1
done
echo "Successfully connected to Skycontroller 2!"
echo
echo "Welcome to Skycontroller 2!"
/data/ftp/uavpal/bin/adb shell 2>/dev/null;
echo "Exiting Skycontroller 2 shell!"