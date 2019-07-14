#!/bin/sh

nodemcu_ip="`head -1 /data/ftp/uavpal/conf/nodemcu_ip |tr -d '\r\n' |tr -d '\n'`"

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -F PREROUTING
iptables -t nat -F POSTROUTING

iptables -t nat -A PREROUTING -p udp --dport 8888 -j DNAT --to-destination $nodemcu_ip:8888
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $nodemcu_ip:80
iptables -t nat -A POSTROUTING -d $nodemcu_ip -p tcp --dport 80 -j SNAT --to 192.168.42.1
