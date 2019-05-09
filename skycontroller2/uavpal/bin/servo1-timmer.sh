#!/bin/sh
sleep $1
killall servo1.sh
/data/lib/ftp/uavpal/bin/servo1.sh $2 $3 &
