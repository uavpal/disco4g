#!/bin/sh

# exports
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp/uavpal/lib

# variables
platform=$(grep 'ro.parrot.build.product' /etc/build.prop | cut -d'=' -f 2)
serial_ctrl_dev=`head -1 /tmp/serial_ctrl_dev |tr -d '\r\n' |tr -d '\n'`
block_dev="$(echo $2 | cut -d "/" -f 3)"
attempt_num=1
mount_timeout=15

# functions
. /data/ftp/uavpal/bin/uavpal_globalfunctions.sh

# main
if [ "$platform" == "evinrude" ]; then
	media_path="/data/ftp/internal_000/Disco/media"
elif [ "$platform" == "ardrone3" ]; then
	media_path="/data/ftp/internal_000/Bebop_2/media"
fi

if [ "$1" == "add" ]; then
	ulogger -s -t uavpal_sdcard "... block device ${block_dev} has been detected, trying to mount"
	mount -t vfat -o rw,noatime /dev/${block_dev} ${media_path}
	title="SD card inserted"
	if [ $? -ne 0 ]; then
		message="could not mount block device ${block_dev} - please ensure the SD card's file system is FAT32 (and not ExFAT!)"
		ulogger -s -t uavpal_sdcard "... ${message}. Exiting!"
		send_message "$message" "$title"
		exit 1
	fi
	ulogger -s -t uavpal_sdcard "... block device ${block_dev} has been mounted successfully"
	diskfree=$(df -h | grep ${block_dev})
	message="photos and videos will now be stored on the SD card (capacity: $(echo $diskfree | awk '{print $2}') / available: $(echo $diskfree | awk '{print $4}'))"
	ulogger -s -t uavpal_sdcard "... ${message}"
	send_message "$message" "$title"

elif [ "$1" == "remove" ]; then
	ulogger -s -t uavpal_sdcard "... block device ${block_dev} has been removed, umounting"
	umount -f $media_path
	diskfree=$(df -h | grep internal_000)
	message="photos and videos will now be stored on the drone's internal memory (capacity: $(echo $diskfree | awk '{print $2}') / available: $(echo $diskfree | awk '{print $4}'))"
	title="SD card removed"
	ulogger -s -t uavpal_sdcard "... ${message}"
	send_message "$message" "$title"
	mkdir ${media_path}
	chmod 755 ${media_path}
	chown root:root ${media_path}
fi
