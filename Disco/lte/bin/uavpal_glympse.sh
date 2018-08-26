#!/bin/sh
BASE_PATH="/data/ftp/internal_000/lte"
DC="${BASE_PATH}/bin/dc"
CURL="${BASE_PATH}/bin/curl"
GLYMPSE_APIKEY_CONF="${BASE_PATH}/etc/glympse_apikey"
PHONENUMBER_CONF="${BASE_PATH}/etc/phonenumber"
UAVPAL_SMS="${BASE_PATH}/bin/uavpal_sms.sh"
PUSHBULLET_CONF="${BASE_PATH}/etc/pushbullet"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${BASE_PATH}/lib

function parse_json()
{
	echo $1 | \
	sed -e 's/[{}]/''/g' | \
	sed -e 's/", "/'\",\"'/g' | \
	sed -e 's/" ,"/'\",\"'/g' | \
	sed -e 's/" , "/'\",\"'/g' | \
	sed -e 's/","/'\"---SEPERATOR---\"'/g' | \
	awk -F=':' -v RS='---SEPERATOR---' "\$1~/\"$2\"/ {print}" | \
	sed -e "s/\"$2\"://" | \
	tr -d "\n\t" | \
	sed -e 's/\\"/"/g' | \
	sed -e 's/\\\\/\\/g' | \
	sed -e 's/^[ \t]*//g' | \
	sed -e 's/^"//'  -e 's/"$//'
}

function gpsDecimal()
{
	gpsVal=$1
	gpsDir="$2"
	gpsInt=$(echo "$gpsVal 100 / p" | $DC)
	gpsMin=$(echo "3k$gpsVal $gpsInt 100 * - p" | $DC)
	gpsDec=$(echo "6k$gpsMin 60 / $gpsInt + 1000000 * p" | $DC | cut -d '.' -f 1)
	if [[ "$gpsDir" != "E" && "$gpsDir" != "N" ]]; then gpsDec="-$gpsDec"; fi
	echo $gpsDec
}

ulogger -s -t uavpal_glympse "... reading Glympse API key from config file"
apikey="`head -1 $GLYMPSE_APIKEY_CONF |tr -d '\r\n' |tr -d '\n'`"
	if [ "$apikey" == "AAAAAAAAAAAAAAAAAAAA" ]; then
		ulogger -s -t uavpal_disco "... disabling Glympse, API key set to ignore"
		exit 0
	fi

ulogger -s -t uavpal_glympse "... reading Disco ID from avahi"
droneName=$(cat /tmp/avahi/services/ardiscovery.service |grep name |cut -d '>' -f 2 |cut -d '<' -f 0)

ulogger -s -t uavpal_glympse "... Glympse API: creating account"
glympseCreateAccount=$($CURL -q -k -H "Content-Type: application/json" -X POST "https://api.glympse.com/v2/account/create?api_key=${apikey}")

ulogger -s -t uavpal_glympse "... Glympse API: logging in"
glympseLogin=$($CURL -q -k -H "Content-Type: application/json" -X POST "https://api.glympse.com/v2/account/login?api_key=${apikey}&id=$(parse_json $glympseCreateAccount id)&password=$(parse_json $glympseCreateAccount password)")

ulogger -s -t uavpal_glympse "... Glympse API: parsing access token"
access_token=$(parse_json $(echo $glympseLogin |sed 's/\:\"access_token/\:\"tmp/g') access_token)

ulogger -s -t uavpal_glympse "... Glympse API: creating ticket"
glympseCreateTicket=$($CURL -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST "https://api.glympse.com/v2/users/self/create_ticket?duration=14400000")

ulogger -s -t uavpal_glympse "... Glympse API: parsing ticket"
ticket=$(parse_json $glympseCreateTicket id)

ulogger -s -t uavpal_glympse "... Glympse API: creating invite"
glympseCreateInvite=$($CURL -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST "https://api.glympse.com/v2/tickets/$ticket/create_invite?type=sms&address=1234567890&send=client")

message="You can track the location of your ${droneName} here: https://glympse.com/$(parse_json ${glympseCreateInvite%_*} id)"
title="${droneName}'s GPS location"

phone_no=`head -1 $PHONENUMBER_CONF |tr -d '\r\n' |tr -d '\n'`
if [ "$phone_no" != "+XXYYYYYYYYY" ]; then
	ulogger -s -t uavpal_glympse "... calling uavpal_sms"
	$UAVPAL_SMS $1 "$phone_no" "$message"
fi

pb_access_token=`head -1 $PUSHBULLET_CONF |tr -d '\r\n' |tr -d '\n'`
if [ "$pb_access_token" != "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ]; then
	ulogger -s -t uavpal_glympse "... sending push notification"
	$CURL -q -k -u ${pb_access_token}: -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"type": "note", "title": "'"$title"'", "body": "'"$message"'"}'
fi

ulogger -s -t uavpal_glympse "... Glympse API: setting identifier to Disco ID"
$CURL -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[{\"t\": $(date +%s)000, \"pid\": 0, \"n\": \"name\", \"v\": \"${droneName}\"}]" "https://api.glympse.com/v2/tickets/$ticket/append_data"

ulogger -s -t uavpal_glympse "... Glympse API: setting Disco thumbnail image"
$CURL -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[{\"t\": $(date +%s)000, \"pid\": 0, \"n\": \"avatar\", \"v\": \"https://uavpal.com/img/disco.png?$(date +%s)\"}]" "https://api.glympse.com/v2/tickets/$ticket/append_data"

ulogger -s -t uavpal_glympse "... Glympse API: reading out Disco's GPS coordinates every 5 seconds to update Glympse via API"

touch /tmp/hilink-signal
touch /tmp/altitude

while true
do
   gps_nmea_out=$(grep GNRMC -m 1 /tmp/gps_nmea_out | cut -c4-)
   lat=$(echo $gps_nmea_out | cut -d ',' -f 4)
   latdir=$(echo $gps_nmea_out | cut -d ',' -f 5)
   latitude="$(gpsDecimal $lat $latdir)"
   long=$(echo $gps_nmea_out | cut -d ',' -f 6)
   longdir=$(echo $gps_nmea_out | cut -d ',' -f 7)
   longitude="$(gpsDecimal $long $longdir)"
   speed=$(printf "%.0f\n" $($DC -e "$(echo $gps_nmea_out | cut -d ',' -f 8) 51.4444 * p"))
   heading="$(printf "%.0f\n" $(echo $gps_nmea_out | cut -d ',' -f 9))"
   altitude="$( cat /tmp/altitude )"
   signal="$( cat /tmp/hilink-signal )"
   droneLabel="${droneName} ${signal} ${altitude}m"

   #echo
   #echo
   #echo "DEBUG: [[$(date +%s)000,$latitude,$longitude,$speed,$heading,$altitude]]"
   #echo

   $CURL -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[[$(date +%s)000,$latitude,$longitude,$speed,$heading,$altitude]]" "https://api.glympse.com/v2/tickets/$ticket/append_location"
   $CURL -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[{\"t\": $(date +%s)000, \"pid\": 0, \"n\": \"name\", \"v\": \"${droneLabel}\"}]" "https://api.glympse.com/v2/tickets/$ticket/append_data" 
   sleep 5
done
exit 0
