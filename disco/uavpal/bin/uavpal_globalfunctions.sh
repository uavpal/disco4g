hilink_api()
{
# Usage: hilink_api {get,post} url-context [json-data]
# Note: callers invoking this function using method "post" do not need to process (echoed) return values, as errors are outputted within the function itself, otherwise the response is <response>OK</response>
#       callers invoking this function using method "get" should handle (echoed) return values using var=$(hilink_api)

	if [ "$1" == "post" ]; then
		method="POST"
	else
		method="GET"
	fi
	url="$2"
	data="$3"

	hilink_router_ip=$(cat /tmp/hilink_router_ip)
	sessionInfo=$(/data/ftp/uavpal/bin/curl -s -X GET "http://${hilink_router_ip}/api/webserver/SesTokInfo" 2>/dev/null)
	if [ "$?" -ne "0" ]; then ulogger -s -t uavpal_hilink_api "... Error connecting to Hi-Link API"; fi

	cookie=$(echo "$sessionInfo" | grep "SessionID=" | cut -b 10-147)
	token=$(echo "$sessionInfo" | grep "TokInfo" | cut -b 10-41)
	result=$(/data/ftp/uavpal/bin/curl -s -X $method "http://${hilink_router_ip}${url}" -d "$data" -H "Cookie: $cookie" -H "__RequestVerificationToken: $token" 2>/dev/null)
	if [ "$?" -ne "0" ]; then ulogger -s -t uavpal_hilink_api "... Error connecting to Hi-Link API"; fi
	if echo "$result" | grep "<error>" ; then ulogger -s -t uavpal_hilink_api "... Hi-Link returned Error Code: $(echo $result | xmllint --xpath 'string(//error/code)' -)"; fi
	echo "$result"
}

firewall()
{
	# Security: block incoming connections on the Internet interface
	# these connections should only be allowed on Wi-Fi (eth0) and via zerotier (zt*)
	ulogger -s -t uavpal_drone "... applying iptables security rules for interface ${1}"
	ip_block='21 23 51 61 873 8888 9050 44444 67 5353 14551'
	for i in $ip_block; do iptables -I INPUT -p tcp -i ${1} --dport $i -j DROP; done
}

connect_hilink()
{
	ulogger -s -t uavpal_connect_hilink "... bringing up Hi-Link network interface"
	ifconfig ${cdc_if} up
	ulogger -s -t uavpal_connect_hilink "... requesting IP address from modem's DHCP server"
	hilink_ip=`udhcpc -i ${cdc_if} -n -t 10 2>&1 |grep obtained | awk '{ print $4 }'`
	hilink_router_ip=$(echo `echo $hilink_ip | cut -d '.' -f 1,2,3`.1)
	ulogger -s -t uavpal_connect_hilink "... setting ${cdc_if}'s IP address to $hilink_ip"
	ifconfig ${cdc_if} ${hilink_ip} netmask 255.255.255.0
	ulogger -s -t uavpal_connect_hilink "... setting default route for $hilink_router_ip"
	ip route add default via ${hilink_router_ip} dev ${cdc_if}
	echo $hilink_ip >/tmp/hilink_ip
	echo $hilink_router_ip >/tmp/hilink_router_ip
	ulogger -s -t uavpal_connect_hilink "... enabling Hi-Link DMZ mode (1:1 NAT for better zerotier performance)"
	hilink_api "post" "/api/security/dmz" "<request><DmzStatus>1</DmzStatus><DmzIPAddress>${hilink_ip}</DmzIPAddress></request>"
	ulogger -s -t uavpal_connect_hilink "... setting Hi-Link NAT type full cone (better zerotier performance)"
	hilink_api "post" "/api/security/nat" "<request><NATType>0</NATType></request>"
	#TODO: confirm whether =0 is really full cone and NOT symmetric!
	ulogger -s -t uavpal_connect_hilink "... querying Huawei device details via Hi-Link API"
	hilink_dev_info=$(hilink_api "get" "/api/device/information")
	ulogger -s -t uavpal_connect_hilink "... model: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//DeviceName)' -), hardware version: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//HardwareVersion)' -)"
	ulogger -s -t uavpal_connect_hilink "... software version: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//SoftwareVersion)' -), WebUI version: $(echo "$hilink_dev_info" | xmllint --xpath 'string(//WebUIVersion)' -)"
}

connect_stick()
{
	ulogger -s -t uavpal_connect_stick "... running pppd to establish connection to mobile network using APN \"$(head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n')\""
	/data/ftp/uavpal/bin/pppd \
		${serial_ppp_dev} \
		connect "/data/ftp/uavpal/bin/chat -v -f  /data/ftp/uavpal/conf/chatscript -T `head -1 /data/ftp/uavpal/conf/apn |tr -d '\r\n' |tr -d '\n'`" \
		noipdefault \
		defaultroute \
		replacedefaultroute \
		hide-password \
		noauth \
		persist \
		usepeerdns \
		maxfail 0 \
		lcp-echo-failure 10 \
		lcp-echo-interval 6 \
		holdoff 5

	until [ -d "/proc/sys/net/ipv4/conf/${ppp_if}" ]; do usleep 100000; done
	ulogger -s -t uavpal_connect_stick "... interface \"${ppp_if}\" is up"
	echo $serial_ctrl_dev >/tmp/serial_ctrl_dev
}

connection_handler_hilink()
{
	while true; do
		check_connection
		if [ $? -ne 0 ]; then
			ulogger -s -t uavpal_connection_handler_hilink "... Internet connection lost, trying to reconnect"
			### manually trigger hangup/kill for hilink via API
			killall -9 udhcpc
			ifconfig ${cdc_if} down
			ip route del default via $(cat /tmp/hilink_router_ip)
			sleep 1
			connect_hilink
		fi
		sleep 5
	done
}

connection_handler_stick()
{ 
	while true; do
		check_connection
		if [ $? -ne 0 ]; then
			ulogger -s -t uavpal_connection_handler_stick "... Internet connection lost, trying to reconnect"
			killall -9 pppd
			killall -9 chat
			ifconfig ${ppp_if} down
			sleep 1
			connect_stick
		fi
		sleep 5
	done
}

check_connection()
{
	ping_retries_per_destination=2
	ping_destinations="8.8.8.8 192.5.5.241 199.7.83.42" # google-public-dns-a.google.com, f.root-servers.org, l.root-servers.org
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