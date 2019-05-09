#!/bin/sh
is_substring(){
	case "$2" in
		*$1*) return 0;;
		*) return 1;;
	esac
}

servo_state=$1
press_seconds=2
input_dev_settings="/dev/input/event0"
nodemcu_ip="`head -1 /data/lib/ftp/uavpal/conf/nodemcu_ip |tr -d '\r\n' |tr -d '\n'`"
if [ $2 == "lte" ]; then
	nodemcu_ip="192.168.42.1"
fi

while true; do
	keystep=0
	evtest ${input_dev_settings} | while read line; do
		if [ $keystep == 0 ]; then
			if is_substring "type 1 (EV_KEY), code 294 (BTN_BASE), value 1" "$line"; then
				killall servo1-timmer.sh
				/data/lib/ftp/uavpal/bin/servo1-timmer.sh $press_seconds $servo_state $2 &	
				servo1_button_timestamp1=$(date "+%s")
				keystep=1
			fi
		else
			if is_substring "type 1 (EV_KEY), code 288 (BTN_TRIGGER), value 0" "$line"; then
				servo1_button_timestamp2=$(date "+%s")
				if [ $(($servo1_button_timestamp2-$servo1_button_timestamp1)) -le $press_seconds ]; then
					if [ $servo_state == 0 ]; then
						echo "11" | ./data/lib/ftp/uavpal/bin/netcat-arm -u ${nodemcu_ip} 8888 -w1&
						servo_state=1
					else
						echo "10" | ./data/lib/ftp/uavpal/bin/netcat-arm -u ${nodemcu_ip} 8888 -w1&
						servo_state=0
					fi				
					killall servo1-timmer.sh
					keystep=0
					ulogger -s -t uavpal_sc2 "... servo1 button press event detected"
				fi
				
			fi
		fi
	done
done

