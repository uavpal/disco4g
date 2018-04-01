#!/bin/sh
echo -e "AT+CMGF=1\rAT+CMGS=\"$1\"\r$2\32" > /dev/ttyUSB0
