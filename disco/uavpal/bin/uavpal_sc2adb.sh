#!/bin/sh
ip_sc2=`netstat -nu |grep 9988 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
until /data/ftp/uavpal/bin/adb connect ${ip_sc2}:9050 2>/dev/null;
do
	echo "Trying to connect to Skycontroller 2 via Wi-Fi"
done
echo "Welcome to Skycontroller 2!"
/data/ftp/uavpal/bin/adb shell 2>/dev/null;
echo "Exiting Skycontroller 2 shell!"