#!/bin/sh
while true
do
   ping -c 1 8.8.8.8 >/dev/null
   rc=$?; if [[ $rc == 0 ]]; then break; fi
   sleep 1
done


cd /data/ftp
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp

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

ntpd -n -d -q
apikey="XXXXX"
droneName=$(cat /tmp/avahi/services/ardiscovery.service |grep name |cut -d '>' -f 2 |cut -d '<' -f 0)
glympseCreateAccount=$(/data/ftp/curl -q -k -H "Content-Type: application/json" -X POST "https://api.glympse.com/v2/account/create?api_key=${apikey}")
glympseLogin=$(/data/ftp/curl -q -k -H "Content-Type: application/json" -X POST "https://api.glympse.com/v2/account/login?api_key=${apikey}&id=$(parse_json $glympseCreateAccount id)&password=$(parse_json $glympseCreateAccount password)")
access_token=$(parse_json $(echo $glympseLogin |sed 's/\:\"access_token/\:\"tmp/g') access_token)
glympseCreateTicket=$(/data/ftp/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST "https://api.glympse.com/v2/users/self/create_ticket?duration=14400000")
ticket=$(parse_json $glympseCreateTicket id)
glympseCreateInvite=$(/data/ftp/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST "https://api.glympse.com/v2/tickets/$ticket/create_invite?type=sms&address=1234567890&send=client")
/data/ftp/sendsms.sh "+XXYYYYYYYYY" "You can track the location of your ${droneName} here: https://glympse.com/$(parse_json ${glympseCreateInvite%_*} id)"
/data/ftp/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[{\"t\": $(date +%s)000, \"pid\": 0, \"n\": \"name\", \"v\": \"${droneName}\"}]" "https://api.glympse.com/v2/tickets/$ticket/append_data"
/data/ftp/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[{\"t\": $(date +%s)000, \"pid\": 0, \"n\": \"avatar\", \"v\": \"https://image.ibb.co/gUZzAF/disco.png?$(date +%s)\"}]" "https://api.glympse.com/v2/tickets/$ticket/append_data"


function gpsDecimal() {
        gpsVal=$1
        gpsDir="$2"
        gpsInt=$(echo "$gpsVal 100 / p" | /data/ftp/dc)
        gpsMin=$(echo "3k$gpsVal $gpsInt 100 * - p" | /data/ftp/dc)
        gpsDec=$(echo "6k$gpsMin 60 / $gpsInt + 1000000 * p" | /data/ftp/dc | cut -d '.' -f 1)
        if [[ "$gpsDir" != "E" && "$gpsDir" != "N" ]]; then gpsDec="-$gpsDec"; fi
        echo $gpsDec
}

while true
do
   gps_nmea_out=$(grep GNRMC -m 1 /tmp/gps_nmea_out | cut -c4-)
   #echo $gps_nmea_out
   lat=$(echo $gps_nmea_out | cut -d ',' -f 4)
   latdir=$(echo $gps_nmea_out | cut -d ',' -f 5)
   long=$(echo $gps_nmea_out | cut -d ',' -f 6)
   longdir=$(echo $gps_nmea_out | cut -d ',' -f 7)
   speed=$(echo $gps_nmea_out | cut -d ',' -f 8)
   # speed does not work properly
   /data/ftp/curl -q -k -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X POST -d "[[$(date +%s)000,$(gpsDecimal $lat $latdir),$(gpsDecimal $long $longdir),0$(/data/ftp/dc -e "$speed 0.514444 * p")]]" "https://api.glympse.com/v2/tickets/$ticket/append_location"
   sleep 5
done

