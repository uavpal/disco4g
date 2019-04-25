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
	if [ -f /tmp/hilink_login_required ]; then
		sessionInfoLogin=$(/data/ftp/uavpal/bin/curl -s -X POST "http://${hilink_router_ip}/api/user/login" -d "<request><Username>admin</Username><Password>$(echo -n "admin" |base64)</Password><password_type>3</password_type></request>" -H "Cookie: $cookie" -H "__RequestVerificationToken: $token" --dump-header - 2>/dev/null)
		if echo -n "$sessionInfoLogin" | grep '<code>108006\|<code>108007' ; then
			ulogger -s -t uavpal_hilink_api "... Hi-Link authentication error. Please disable password protection or set it to user=admin, password=admin"
			return # break out function
		fi
		cookie=$(echo -n "$sessionInfoLogin" | grep "SessionID=" | cut -d ':' -f2 | cut -d ';' -f1)
		token=$(echo -n "$sessionInfoLogin" | grep "__RequestVerificationTokenone" | cut -d ':' -f2)
		sessionInfoAdm=$(curl -s -X GET "http://${hilink_router_ip}/api/webserver/SesTokInfo" -H "Cookie: $cookie" 2>/dev/null)
		token=$(echo "$sessionInfoAdm" | grep "TokInfo" | cut -b 10-41)
	fi
	result=$(/data/ftp/uavpal/bin/curl -s -X $method "http://${hilink_router_ip}${url}" -d "$data" -H "Cookie: $cookie" -H "__RequestVerificationToken: $token" 2>/dev/null)
	if echo "$result" | grep "<error>" ; then
		if [ "$(echo $result | xmllint --xpath 'string(//error/code)' -)" -eq "100003" ]; then
			ulogger -s -t uavpal_hilink_api "... Hi-Link authentication required. Trying to login using user=admin, password=admin"
			touch /tmp/hilink_login_required
			result=$(hilink_api "$1" "$2" "$3")
		else
			ulogger -s -t uavpal_hilink_api "... Hi-Link returned Error Code: $(echo $result | xmllint --xpath 'string(//error/code)' -)"
		fi
	fi
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

conf_read()
{
	result=$(head -1 /data/ftp/uavpal/conf/${1})
	echo "$result" |tr -d '\r\n' |tr -d '\n'
}

at_command()
{
	command="$1"
	expected_response="$2"
	timeout="$3"
	result=$(/data/ftp/uavpal/bin/chat -V -t $timeout '' "$command" "$expected_response" '' > /dev/${serial_ctrl_dev} < /dev/${serial_ctrl_dev}) 2>&1
	if [ "$?" -ne "0" ]; then ulogger -s -t uavpal_at_command "... Did not receive expected output from AT command $command"; fi
	echo "$result"
}

send_message()
{
	# delay sending of messages if modem is not yet online
	for i in 1 2 3; do
		check_connection
	done
	if [ $? -ne 0 ]; then
		ulogger -s -t uavpal_send_message "... Cannot send message (no connection). Exiting send_message function!"
		exit 1 # exit function
	fi
	phone_no="$(conf_read phonenumber)"
	if [ "$phone_no" != "+XXYYYYYYYYY" ]; then
		if [ ! -f "/tmp/hilink_router_ip" ]; then
			ulogger -s -t uavpal_send_message "... sending SMS to ${phone_no} (via ${serial_ctrl_dev})"
			at_command "AT+CMGF=1\rAT+CMGS=\"${phone_no}\"\r${1}\32" "OK" "2"
		else
			ulogger -s -t uavpal_send_message "... sending SMS to ${phone_no} (via Hi-Link API)"
			hilink_api "post" "/api/sms/send-sms" "<request><Index>-1</Index><Phones><Phone>${phone_no}</Phone></Phones><Sca></Sca><Content>${1}</Content><Length>-1</Length><Reserved>-1</Reserved><Date>-1</Date></request>"
		fi
	fi
	
	pb_access_token="$(conf_read pushbullet)"
	if [ "$pb_access_token" != "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ]; then
		ulogger -s -t uavpal_send_message "... sending push notification (via Pushbullet API)"
		/data/ftp/uavpal/bin/curl -q -k -u ${pb_access_token}: -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"type": "note", "title": "'"$2"'", "body": "'"$1"'"}'
	fi
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
	echo $hilink_router_ip >/tmp/hilink_router_ip
	hilink_profiles=$(hilink_api "get" "/api/dialup/profiles")
	hilink_apn_index=$(echo $hilink_profiles | xmllint --xpath "string(//CurrentProfile)" -)
	hilink_apn=$(echo $hilink_profiles | xmllint --xpath "string(//Profile[${hilink_apn_index}]/ApnName)" -)
	ulogger -s -t uavpal_connect_hilink "... connecting to mobile network using APN \"${hilink_apn}\" (configured in the Hi-Link Web UI)"
}

connect_stick()
{
	ulogger -s -t uavpal_connect_stick "... running pppd to establish connection to mobile network using APN \"$(conf_read apn)\" (configured in the conf/apn file)"
	/data/ftp/uavpal/bin/pppd \
		${serial_ppp_dev} \
		connect "/data/ftp/uavpal/bin/chat -v -f  /data/ftp/uavpal/conf/chatscript -T $(conf_read apn)" \
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
			hilink_api "post" "/api/dialup/mobile-dataswitch" "<request><dataswitch>0</dataswitch></request>"
			sleep 1
			hilink_api "post" "/api/dialup/mobile-dataswitch" "<request><dataswitch>1</dataswitch></request>"
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