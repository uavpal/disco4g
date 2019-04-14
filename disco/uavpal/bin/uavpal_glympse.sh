#!/bin/sh

# exports
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

# variables
platform=$(grep 'ro.parrot.build.product' /etc/build.prop | cut -d'=' -f 2)
serial_ctrl_dev=`head -1 /tmp/serial_ctrl_dev |tr -d '\r\n' |tr -d '\n'`

# functions
. /data/ftp/uavpal/bin/uavpal_globalfunctions.sh

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
	gpsInt=$(echo "$gpsVal 100 / p" | /data/ftp/uavpal/bin/dc)
	gpsMin=$(echo "3k$gpsVal $gpsInt 100 * - p" | /data/ftp/uavpal/bin/dc)
	gpsDec=$(echo "6k$gpsMin 60 / $gpsInt + 1000000 * p" | /data/ftp/uavpal/bin/dc | cut -d '.' -f 1)
	if [[ "$gpsDir" != "E" && "$gpsDir" != "N" ]]; then gpsDec="-$gpsDec"; fi
	echo $gpsDec
}

# main
ulogger -s -t uavpal_glympse "... reading Glympse API key from config file"
apikey="$(conf_read glympse_apikey)"
if [ "$apikey" == "AAAAAAAAAAAAAAAAAAAA" ]; then
	ulogger -s -t uavpal_glympse "... disabling Glympse, API key set to ignore"
	exit 0
fi

ulogger -s -t uavpal_glympse "... reading drone ID from avahi"
droneName=$(cat /tmp/avahi/services/ardiscovery.service |grep name |cut -d '>' -f 2 |cut -d '<' -f 0)

ulogger -s -t uavpal_glympse "... Glympse API: creating account"
glympseCreateAccount=$(/data/ftp/uavpal/bin/curl -q -k -H "Content-Type: application/json" -X POST "https://api.glympse.com/v2/account/create?api_key=${apikey}")

ulogger -s -t uavpal_glympse "... Glympse API: logging in"
glympseLogin=$(/data/ftp/uavpal/bin/curl -q -k -H "Content-Type: application/json" -X POST "https://api.glympse.com/v2/account/login?api_key=${apikey}&id=$(parse_json $glympseCreateAccount id)&password=$(parse_json $glympseCreateAccount password)")

ulogger -s -t uavpal_glympse "... Glympse API: parsing access token"
access_token=$(parse_json $(echo $glympseLogin |sed 's/\:\"access_token/\:\"tmp/g') access_token)

ulogger -s -t uavpal_glympse "... Glympse API: creating ticket"
glympseCreateTicket=$(/data/ftp/uavpal/bin/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST "https://api.glympse.com/v2/users/self/create_ticket?duration=14400000")

ulogger -s -t uavpal_glympse "... Glympse API: parsing ticket"
ticket=$(parse_json $glympseCreateTicket id)

ulogger -s -t uavpal_glympse "... Glympse API: creating invite"
glympseCreateInvite=$(/data/ftp/uavpal/bin/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST "https://api.glympse.com/v2/tickets/$ticket/create_invite?type=sms&address=1234567890&send=client")

ulogger -s -t uavpal_glympse "... Glympse link generated: https://glympse.com/$(parse_json ${glympseCreateInvite%_*} id)"

message="You can track the location of your ${droneName} here: https://glympse.com/$(parse_json ${glympseCreateInvite%_*} id)"
title="${droneName}'s GPS location"

phone_no="$(conf_read phonenumber)"
if [ "$phone_no" != "+XXYYYYYYYYY" ]; then
	if [ "$1" == "stick" ]; then
		ulogger -s -t uavpal_glympse "... sending SMS with Glympse link to ${phone_no} (via ${serial_ctrl_dev})"
		at_command "AT+CMGF=1\rAT+CMGS=\"${phone_no}\"\r${message}\32" "OK" "2"
	elif [ "$1" == "hilink" ]; then
		ulogger -s -t uavpal_glympse "... sending SMS with Glympse link to ${phone_no} (via Hi-Link API)"
		hilink_api "post" "/api/sms/send-sms" "<request><Index>-1</Index><Phones><Phone>${phone_no}</Phone></Phones><Sca></Sca><Content>${message}</Content><Length>-1</Length><Reserved>-1</Reserved><Date>-1</Date></request>"
	fi
fi

pb_access_token="$(conf_read pushbullet)"
if [ "$pb_access_token" != "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ]; then
	ulogger -s -t uavpal_glympse "... sending push notification"
	/data/ftp/uavpal/bin/curl -q -k -u ${pb_access_token}: -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"type": "note", "title": "'"$title"'", "body": "'"$message"'"}'
fi

ulogger -s -t uavpal_glympse "... Glympse API: setting drone thumbnail image"
if [ "$platform" == "evinrude" ]; then
	# Parrot Disco
	tn_filename="disco.png"
elif [ "$platform" == "ardrone3" ]; then
	# Parrot Bebop 2
	tn_filename="bebop2.png"
fi
/data/ftp/uavpal/bin/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[{\"t\": $(date +%s)000, \"pid\": 0, \"n\": \"avatar\", \"v\": \"https://uavpal.com/img/${tn_filename}?$(date +%s)\"}]" "https://api.glympse.com/v2/tickets/$ticket/append_data"

ztVersion=$(/data/ftp/uavpal/bin/zerotier-one -v)

ulogger -s -t uavpal_glympse "... Glympse API: reading out drone's GPS coordinates every 5 seconds to update Glympse via API"

# initializing vars
bat_volts="n/a"
bat_percent="n/a"

while true
do
	gps_nmea_out=$(grep GNRMC -m 1 /tmp/gps_nmea_out | cut -c4-)
	lat=$(echo $gps_nmea_out | cut -d ',' -f 4)
	latdir=$(echo $gps_nmea_out | cut -d ',' -f 5)
	long=$(echo $gps_nmea_out | cut -d ',' -f 6)
	longdir=$(echo $gps_nmea_out | cut -d ',' -f 7)
	speed=$(printf "%.0f\n" $(/data/ftp/uavpal/bin/dc -e "$(echo $gps_nmea_out | cut -d ',' -f 8) 51.4444 * p"))
	heading="$(printf "%.0f\n" $(echo $gps_nmea_out | cut -d ',' -f 9))"
	altitude_abs=$(grep GNGNS -m 1 /tmp/gps_nmea_out | cut -c4- | cut -d ',' -f 10)

	if [ -f /data/ftp/internal_000/*/academy/*.pud.temp ]; then
		altitude_rel=$(/data/ftp/uavpal/bin/dc -e "$altitude_abs $(cat /tmp/alt_before_takeoff) - p")
	else
		echo $altitude_abs > /tmp/alt_before_takeoff
		altitude_rel="0"
  fi

	if [ `cat /tmp/sc2ping | wc -l` -eq '1' ]; then
		latency=$(/data/ftp/uavpal/bin/dc -e "$(cat /tmp/sc2ping) 2 / p")ms
	else
		latency="n/a"
	fi

	if [ "$platform" == "evinrude" ]; then
		# Parrot Disco
		bat_msb="00" && while [[ $bat_msb == "00" -o $bat_msb == "01" ]]; do bat_msb=$(i2cdump -r 0x20-0x23 -y 1 0x08 |tail -1 | cut -d " " -f 4); done
		bat_lsb="00" && while [[ $bat_lsb == "00" -o $bat_lsb == "01" ]]; do bat_lsb=$(i2cdump -r 0x20-0x23 -y 1 0x08 |tail -1 | cut -d " " -f 5); done
	elif [ "$platform" == "ardrone3" ]; then
		# Parrot Bebop 2
		bat_msb="00" && while [[ $bat_msb == "00" -o $bat_msb == "01" ]]; do bat_msb=$(i2cdump -r 0x20-0x29 -y 1 0x08 |tail -1 | cut -d " " -f 10); done
		bat_lsb="00" && while [[ $bat_lsb == "00" -o $bat_lsb == "01" ]]; do bat_lsb=$(i2cdump -r 0x20-0x29 -y 1 0x08 |tail -1 | cut -d " " -f 11); done
	fi
	bat_volts_prev=$bat_volts
	bat_volts=$(/data/ftp/uavpal/bin/dc -e "2k $(printf "%d\n" 0x${bat_msb}${bat_lsb}) 1000 / p")
	# skip battery voltage (use previous value) if it's higher than 13.5V - sometimes unrealistic values are returned by i2cdump
	if [ "$(echo $bat_volts | awk '{print int($1+0.5)}')" -gt "13" ]; then bat_volts="$bat_volts_prev"; fi
	
	bat_percent_prev=$bat_percent
	bat_percent=$(ulogcat -d -v csv |grep "Battery percentage" |tail -n 1 | cut -d " " -f 4)
	if [ -z "$bat_percent" ]; then bat_percent="$bat_percent_prev"; fi

	ip_sc2=`netstat -nu |grep 9988 | head -1 | awk '{ print $5 }' | cut -d ':' -f 1`
	ztConn=""
	if [ `echo $ip_sc2 | awk -F. '{print $1"."$2"."$3}'` == "192.168.42" ]; then
		signal="Wi-Fi"
	else
		# detect if zerotier connection is direct vs. relayed
		if [ $(/data/ftp/uavpal/bin/zerotier-one -q listpeers |grep LEAF |grep $ztVersion |grep -v ' - ' | wc -l) != '0' ] && [ "$ip_sc2" != "" ]; then
			ztConn=" [D]"
		fi
		if [ $(/data/ftp/uavpal/bin/zerotier-one -q listpeers |grep LEAF |grep $ztVersion |grep -v ' - ' | wc -l) == '0' ] && [ "$ip_sc2" != "" ]; then
			ztConn=" [R]"
		fi

		# reading out the modem's connection type and ignal strength
		if [ "$1" == "stick" ]; then
			modeString=$(at_command "AT\^SYSINFOEX" "OK" "1" | grep "SYSINFOEX:" | tail -n 1)
			modeNum=`echo $modeString | cut -d "," -f 8`
			if [ $modeNum -ge 101 ]; then
				mode="4G"
			elif [ $modeNum -ge 23 ] && [ $modeNum -le 65 ]; then
				mode="3G"
			elif [ $modeNum -ge 1 ] && [ $modeNum -le 3 ]; then
				mode="2G"
			else
				mode="n/a"
			fi
			signalString=$(at_command "AT+CSQ" "OK" "1" | grep "CSQ:" | tail -n 1)
			signalRSSI=`echo $signalString | awk '{print $2}' | cut -d ',' -f 1`
			if [ $signalRSSI -ge 0 ] && [ $signalRSSI -le 31 ]; then
				signalPercentage=$(printf "%.0f\n" $(/data/ftp/uavpal/bin/dc -e "$(echo $signalRSSI) 1 + 3.13 * p"))%
			else # including 99 for "Unknown or undetectable"
				signalPercentage="n/a"
			fi
			signal="$mode/$signalPercentage"
		elif [ "$1" == "hilink" ]; then
			# TODO: add Hilink way for 3G vs. 4G and signal strength!
			###<supportmode>LTE|WCDMA|GSM</supportmode>
			###<workmode>LTE</workmode>
			echo ###
		fi
	fi

	droneLabel="${droneName} (Sig:${signal} Alt:${altitude_rel}m Bat:${bat_percent}%/${bat_volts}V Ltn:${latency}${ztConn})"
	ulogger -s -t uavpal_glympse "... updating Glympse label: $droneLabel"

	/data/ftp/uavpal/bin/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[[$(date +%s)000,$(gpsDecimal $lat $latdir),$(gpsDecimal $long $longdir),$speed,$heading]]" "https://api.glympse.com/v2/tickets/$ticket/append_location" &
	/data/ftp/uavpal/bin/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[{\"t\": $(date +%s)000, \"pid\": 0, \"n\": \"name\", \"v\": \"${droneLabel}\"}]" "https://api.glympse.com/v2/tickets/$ticket/append_data" &

	if test -n "$ip_sc2"; then
		ping -c 1 $ip_sc2 |grep 'bytes from' | cut -d '=' -f 4 | tr -d ' ms' > /tmp/sc2ping &
	else
		rm /tmp/sc2ping 2>/dev/null
	fi
	sleep 5
	# make sure all curl processes have ended
	while ps |grep curl |grep -v grep >/dev/null; do usleep 100000; done
done

