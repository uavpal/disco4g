#!/bin/sh
main()
{
	# variables
	wifi_connection_attempts=5
	wifi_connection_timeout_seconds=7
	wifi_dhcp_timeout_seconds=10
	zerotier_iface_timeout_seconds=5
	disco4g_ping_retry=20
	settings_double_press_seconds=2

	# set tmp files values (cheap workaround for local variable scope issue in while loops)
	echo wifi >/tmp/mode
	echo 0 >/tmp/button_prev_timestamp

	# background pinging of disco via zt*, change LED to blue if ping ok - needed to override green LED after a successful mppd reconnect
	while true; do if ping -c 1 -I `head -1 /tmp/zt_interface` 192.168.42.1 >/dev/null 2>&1; then mpp_bb_cli on 3; fi; sleep 1; done &

	# wait for mppd to be idle (to absorb the power button press from a cold start)
	until [ "$(ulogcat -d |grep mppd |grep "state=IDLE" |wc -l)" -gt "0" ]; do sleep 1; done

	# background listener for power button - needed for the time when mppd is paused, e.g. to turn off controller - currently reboot only, how to shutdown?
	# TODO: ideally, only activate this listener when required and kill afterwards
	/data/lib/ftp/uavpal/bin/jstest --event /dev/input/js0 | grep -m 1 -E "type 1,.*number 7, value 1" | while read ; do killall -SIGCONT mppd ; done &

	while true
	do
		# wait for Settings button event
		while true
		do
			/data/lib/ftp/uavpal/bin/jstest --event /dev/input/js0 | grep -m 1 -E "type 1,.*number 0, value 1" | while read ; do date "+%s" >/tmp/button_timestamp ; done
			button_prev_timestamp=$(cat /tmp/button_prev_timestamp)
			button_timestamp=$(cat /tmp/button_timestamp)
			if [ "$(($button_timestamp-$button_prev_timestamp))" -lt "$settings_double_press_seconds" ]; then
				ulogger -s -t uavpal_sc2 "Settings button double press event detected"
				break # break out of loop
			fi
			cp /tmp/button_timestamp /tmp/button_prev_timestamp
		done
		if [ "$(cat /tmp/mode)" == "lte" ]; then
			switch_to_wifi
		else
			switch_to_lte
		fi
		ulogger -s -t uavpal_sc2 "removing jstest crash reports"
		# this is currently required as jstest crashes for every button event which fills the logs (disk space issue)
		rm -rf /data/lib/ftp/internal_000/Debug/crash_reports/report_*
	done
}


switch_to_lte()
{
	echo lte >/tmp/mode
	ulogger -s -t uavpal_sc2 "=== Switching to LTE ==="
	ulogger -s -t uavpal_sc2 "... indicating switch-over to LTE for 1 seconds (LED flashing blue/white)"
	mpp_bb_cli blink 7 3 200 20
	sleep 1
	ulogger -s -t uavpal_sc2 "... changing LED to flashing magenta"
	mpp_bb_cli blink 6 0 1000 50

	ulogger -s -t uavpal_sc2 "... pausing process mppd"
	killall -SIGSTOP mppd

	ulogger -s -t uavpal_sc2 "... pausing process wifid"
	killall -SIGSTOP wifid

	ulogger -s -t uavpal_sc2 "... launching process wifid-uavpal in the background"
	WIFID_DRIVER=bcmdriver /usr/bin/wifid --mode STA --ip 192.168.42.3 --suffix uavpal &

	for p in `seq 1 $wifi_connection_attempts`
	do
		ulogger -s -t uavpal_sc2 "... connecting to mobile Wi-Fi hotspot (try $p of $wifi_connection_attempts)"

		wifid-cli --suffix uavpal connect "`head -1 /data/lib/ftp/uavpal/conf/ssid |tr -d '\r\n' |tr -d '\n'`" 0 "`head -1 /data/lib/ftp/uavpal/conf/wpa |tr -d '\r\n' |tr -d '\n'`"
		
		for q in `seq 1 $wifi_connection_timeout_seconds`; do
			sleep 1
			wifi_connection_status=`wifid-cli --suffix uavpal status 2>&1 |grep state |awk '{print $3}'`
			if [ "$wifi_connection_status" = "connected" ]; then
				ulogger -s -t uavpal_sc2 "... Wi-Fi successfully connected"
				break 2 # break out of both for loops
			fi
		done
		if [ "$p" -eq "$wifi_connection_timeout_seconds" ]; then
			ulogger -s -t uavpal_sc2 "... $wifi_connection_attempts unsuccessful Wi-Fi connection attempts reached - switching back to Wi-Fi"
			switch_to_wifi
			return # back to main()
		fi
	done

	ulogger -s -t uavpal_sc2 "... requesting IP address via DHCP from mobile Wi-Fi hotspot"
	udhcpc -i wlan0 -f &
	for p in `seq 1 $wifi_dhcp_timeout_seconds`
	do
		wifi_dhcp_ip=`ifconfig wlan0 |grep inet |awk '{print $2}' |grep -v '192.168.42' |wc -l`
		if [ "$wifi_dhcp_ip" = "1" ]; then
			ulogger -s -t uavpal_sc2 "... IP address successfully obtained from DHCP via Wi-Fi"
			break # break out of loop
		fi
		sleep 1
		if [ "$p" -eq "$wifi_dhcp_timeout_seconds" ]; then
			ulogger -s -t uavpal_sc2 "... no IP received via DHCP after $wifi_dhcp_timeout_seconds seconds - switching back to Wi-Fi"
			switch_to_wifi
			return # back to main()
		fi
	done

	ulogger -s -t uavpal_sc2 "... changing LED to flashing blue"
	mpp_bb_cli blink 3 0 1000 50

	ulogger -s -t uavpal_sc2 "... removing default route (in case USB Ethernet is attached)"
	ip route del default dev eth0

	ulogger -s -t uavpal_sc2 "... terminating process wifid-uavpal"
	kill -9 `ps |grep wifid |grep suffix |awk '{print $1}'`

	ulogger -s -t uavpal_sc2 "... starting zerotier daemon"
	/data/lib/ftp/uavpal/bin/zerotier-one -d

	if [ ! -d "/data/lib/zerotier-one/networks.d" ]; then
		ulogger -s -t uavpal_sc2 "... (initial-)joining zerotier network ID"
		while true
		do
			ztjoin_response=`/data/lib/ftp/uavpal/bin/zerotier-one -q join $(head -1 /data/lib/ftp/uavpal/conf/zt_networkid |tr -d '\r\n' |tr -d '\n')`
			if [ "`echo $ztjoin_response |head -n1 |awk '{print $1}')`" == "200" ]; then
				ulogger -s -t uavpal_sc2 "... successfully joined zerotier network ID"
				break # break out of loop
			else
				ulogger -s -t uavpal_sc2 "... ERROR joining zerotier network ID: $ztjoin_response - trying again"
				sleep 1
			fi
		done
	fi

	for p in `seq 1 $zerotier_iface_timeout_seconds`
	do
		zt_interface=`/data/lib/ftp/uavpal/bin/zerotier-one -q listnetworks -j |grep portDeviceName | cut -d '"' -f 4`
		if ip route add 192.168.42.1/32 dev $zt_interface; then
			ulogger -s -t uavpal_sc2 "... added IP route for disco via zerotier interface $zt_interface successfully"
			echo $zt_interface >/tmp/zt_interface
			break # break out of loop
		fi
		sleep 1
		if [ "$p" -eq "$zerotier_iface_timeout_seconds" ]; then
			ulogger -s -t uavpal_sc2 "... zerotier IP route for disco could not be set - most probably due to zerotier daemon not bringing up the network interface zt* within $zerotier_iface_timeout_seconds seconds - switching back to Wi-Fi"
			switch_to_wifi
			return # back to main()
		fi
	done

	for p in `seq 1 $disco4g_ping_retry`
	do
		ulogger -s -t uavpal_sc2 "... trying to ping disco via 4G/LTE through zerotier (try $p of $disco4g_ping_retry)"
		if ping -c 1 -I $zt_interface 192.168.42.1 >/dev/null 2>&1; then
			ulogger -s -t uavpal_sc2 "... successfully received ping echo from disco via zerotier over 4G/LTE"
			break # break out of loop
		fi
		if [ "$p" -eq "$disco4g_ping_retry" ]; then
			ulogger -s -t uavpal_sc2 "... could not ping disco via zerotier over 4G/LTE in $disco4g_ping_retry attempts - switching back to Wi-Fi"
			switch_to_wifi
			return # back to main()
		fi
	done

	ulogger -s -t uavpal_sc2 "... resuming process mppd"
	killall -SIGCONT mppd

	ulogger -s -t uavpal_sc2 "*** idle on LTE ***"
}


switch_to_wifi()
{
	echo wifi >/tmp/mode
	ulogger -s -t uavpal_sc2 "=== Switching to Wifi ==="
	ulogger -s -t uavpal_sc2 "... indicating switch-over to Wi-Fi for 1 seconds (LED flashing green/white)"
	mpp_bb_cli blink 7 4 200 20
	sleep 1
	ulogger -s -t uavpal_sc2 "... resuming process mppd (should already be resumed though)"
	killall -SIGCONT mppd
	ulogger -s -t uavpal_sc2 "... restarting process wifid"
	killall -9 wifid
	ulogger -s -t uavpal_sc2 "... terminating processes required for LTE"
	killall zerotier-one
	killall udhcpc
	ulogger -s -t uavpal_sc2 "*** idle on Disco Wifi (or at least trying to connect) ***"
}

main "$@"
