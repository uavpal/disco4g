#!/bin/sh

# exports
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

# variables
platform=$(grep 'ro.parrot.build.product' /etc/build.prop | cut -d'=' -f 2)
serial_ctrl_dev=`head -1 /tmp/serial_ctrl_dev |tr -d '\r\n' |tr -d '\n'`
partition="$(echo $2 | cut -d "/" -f 3)"
disk="$(echo $partition | rev | cut -c 2- | rev)"
bb2_led="/sys/devices/platform/leds_pwm/leds/milos:super_led/brightness"

# functions
. /data/ftp/uavpal/bin/uavpal_globalfunctions.sh

led_indicate_external () {
	if [ "$platform" == "evinrude" ]; then
		ldc set_pattern color_wheel true
		sleep 5
		ldc set_pattern idle true
	elif [ "$platform" == "ardrone3" ]; then
		brightness=0
		old_brightness=$(cat $bb2_led)
		for i in $(seq 0 15); do
			echo $(expr $brightness + $i \* 10) >$bb2_led
			usleep 25000
		done
		echo ${old_brightness} > $bb2_led
	fi
}

led_indicate_internal () {
	if [ "$platform" == "evinrude" ]; then
		ldc set_pattern demo_low_bat true
		sleep 3
		ldc set_pattern idle true
	elif [ "$platform" == "ardrone3" ]; then
		brightness=150
		old_brightness=$(cat $bb2_led)
		for i in $(seq 0 15); do
			echo $(expr $brightness - $i \* 10) >$bb2_led
			usleep 25000
		done
		echo ${old_brightness} > $bb2_led
	fi
}

# main
if [ "$platform" == "evinrude" ]; then
	media_path="/data/ftp/internal_000/Disco/media"
elif [ "$platform" == "ardrone3" ]; then
	media_path="/data/ftp/internal_000/Bebop_2/media"
fi

if [ "$1" == "add" ]; then
	last_partition=$(ls /dev/${disk}? | tail -n 1)
	if [ "$last_partition" != "/dev/${partition}" ]; then
		exit 1 # only proceed if the last partition has triggered the script (necessary for GPT partition tables)
	fi
	ulogger -s -t uavpal_sdcard "... disk ${disk} has been detected, trying to mount its last partition ${partition}"
	title="SD card inserted"
	mount -t vfat -o rw,noatime /dev/${partition} ${media_path}
	if [ $? -ne 0 ]; then
		message="could not mount SD card partition ${partition} - please ensure the SD card's file system is FAT32 (and not exFAT!)"
		ulogger -s -t uavpal_sdcard "... ${message}. Exiting!"
		send_message "$message" "$title" &
		led_indicate_internal
		exit 1
	fi
	ulogger -s -t uavpal_sdcard "... partition ${partition} has been mounted successfully"
	diskfree=$(df -h | grep ${partition})
	message="photos and videos will now be stored on the SD card (capacity: $(echo $diskfree | awk '{print $2}') / available: $(echo $diskfree | awk '{print $4}'))"
	ulogger -s -t uavpal_sdcard "... ${message}"
	send_message "$message" "$title" &
	led_indicate_external
elif [ "$1" == "remove" ]; then
	ulogger -s -t uavpal_sdcard "... disk ${disk} has been removed"
	umount -f ${media_path}
	diskfree=$(df -h | grep internal_000)
	message="photos and videos will now be stored on the drone's internal memory (capacity: $(echo $diskfree | awk '{print $2}') / available: $(echo $diskfree | awk '{print $4}'))"
	title="SD card removed"
	ulogger -s -t uavpal_sdcard "... ${message}"
	send_message "$message" "$title" &
	mkdir ${media_path}
	chmod 755 ${media_path}
	chown root:root ${media_path}
	led_indicate_internal
fi
