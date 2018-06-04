#!/bin/sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

ulogger -s -t uavpal_hilink "... reading Hi-Link modem's WAN IP"
while true
do
	sessionInfo=`/data/ftp/uavpal/bin/curl -s -X GET "http://$1/api/webserver/SesTokInfo"`
	cookie=`echo "$sessionInfo" | grep "SessionID=" | cut -b 10-147`
	token=`echo "$sessionInfo" | grep "TokInfo" | cut -b 10-41`
	wan_ip=`/data/ftp/uavpal/bin/curl -s -X GET "http://$1/api/monitoring/status" -H "Cookie: $cookie" -H "__RequestVerificationToken: $token" | awk -F '[<>]' '/WanIPAddress/{print $3}'`
	if [ ${#wan_ip} -ge 7 ]; then
		ulogger -s -t uavpal_hilink "... found WAN IP: ${wan_ip}"
		break # break out of loop
	else
		sleep 2
	fi
done

zt_drone_id=`cat /data/lib/zerotier-one/networks.d/*.conf |grep id |grep -v nwid |head -1 |cut -d '=' -f 2`
if [ ${#zt_drone_id} -ne 10 ]; then
	ulogger -s -t uavpal_hilink "... drone's zerotier ID could not be found, exiting script"
	exit
else
	ulogger -s -t uavpal_hilink "... drone's zerotier ID: ${zt_drone_id}"
fi

ulogger -s -t uavpal_hilink "... compiling zerotier local.conf file for Skycontroller 2"
localconf="{
    \"virtual\": {
        \"${zt_drone_id}\": {
            \"role\": \"UPSTREAM\",
            \"try\": [ \"${wan_ip}/9993\" ]
        }
    },
    \"settings\": {
        \"interfacePrefixBlacklist\": [ \"eth0\" ]
    }
}"

ulogger -s -t uavpal_hilink "... trying to find Skycontroller 2 via direct Wi-Fi connection"
while true
do
	sc2_wifi_ip=`netstat -nu |grep 9988 |grep 192.168.42 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
	if [ ${#sc2_wifi_ip} -ge 12 ]; then
		ulogger -s -t uavpal_hilink "... found Skycontroller 2 Wi-Fi IP: ${sc2_wifi_ip}"
		break # break out of loop
	else
		sleep 1
	fi
done

until /data/ftp/uavpal/bin/adb connect ${sc2_wifi_ip}:9050;
do
	ulogger -s -t uavpal_hilink "... trying to connect from Drone to Skycontroller 2 via Wi-Fi"
done
ulogger -s -t uavpal_hilink "... writing zerotier local.conf with drone's WAN IP to Skycontroller 2"
/data/ftp/uavpal/bin/adb shell "echo \"${localconf}\" >data/lib/zerotier-one/local.conf"
