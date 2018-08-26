#!/bin/sh
BASE_PATH="/data/ftp/internal_000/lte"
CURL="${BASE_PATH}/bin/curl"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${BASE_PATH}/lib

if [ "$1" == "stick" ]; then
	ulogger -s -t uavpal_sms "... sending SMS with Glympse link (via ttyUSB)"
	echo -e "AT+CMGF=1\rAT+CMGS=\"$2\"\r$3\32" > /dev/ttyUSB0
elif [ "$1" == "hilink" ]; then
	ulogger -s -t uavpal_sms "... sending SMS with Glympse link (via Hi-Link API)"
	hilink_router_ip=$(ip route | grep default | grep eth1 | awk '{ print $3 }')
	sessionInfo=$($CURL -s -X GET "http://${hilink_router_ip}/api/webserver/SesTokInfo")
	cookie=$(echo "$sessionInfo" | grep "SessionID=" | cut -b 10-147)
	token=$(echo "$sessionInfo" | grep "TokInfo" | cut -b 10-41)
	$CURL -s -X POST "http://${hilink_router_ip}/api/sms/send-sms" -d "<request><Index>-1</Index><Phones><Phone>$2</Phone></Phones><Sca></Sca><Content>$3</Content><Length>-1</Length><Reserved>-1</Reserved><Date>-1</Date></request>" -H "Cookie: $cookie" -H "__RequestVerificationToken: $token"
else
	ulogger -s -t uavpal_sms "ERROR: the first argument has to be stick|hilink"
fi
exit 0