#!/bin/sh

# variables
platform=$(grep 'ro.parrot.build.product' /etc/build.prop | cut -d'=' -f 2)
block_dev="$(echo $2 | cut -d "/" -f 3)"
attempt_num=1
mount_timeout=15

# main
if [ "$platform" == "evinrude" ]; then
	media_path="/data/ftp/internal_000/Disco/media"
elif [ "$platform" == "ardrone3" ]; then
	media_path="/data/ftp/internal_000/Bebop_2/media"
fi

if [ "$1" == "add" ]; then
	ulogger -s -t uavpal_sdcard "... block device ${block_dev} has been detected, trying to mount"
	mount -o rw,noatime /dev/${block_dev} ${media_path}
	if [ $? -ne 0 ]; then
		ulogger -s -t uavpal_sdcard "... could not mount block device ${block_dev} - please ensure the SD card's file system is FAT32 (and not ExFAT!). Exiting!"
		exit 1
	fi
	ulogger -s -t uavpal_sdcard "... block device ${block_dev} has been mounted successfully"
	diskfree=$(df -h | grep ${block_dev})
	ulogger -s -t uavpal_sdcard "... photos and videos will now be stored on the SD card (capacity: $(echo $diskfree | awk '{print $2}') / available: $(echo $diskfree | awk '{print $4}'))"

elif [ "$1" == "remove" ]; then
	ulogger -s -t uavpal_sdcard "... block device ${block_dev} has been removed, umounting"
	umount -f $media_path
	diskfree=$(df -h | grep internal_000)
	ulogger -s -t uavpal_sdcard "... photos and videos will now be stored on the drone's internal memory (capacity: $(echo $diskfree | awk '{print $2}') / available: $(echo $diskfree | awk '{print $4}'))"
	mkdir ${media_path}
	chmod 755 ${media_path}
	chown root:root ${media_path}
fi
