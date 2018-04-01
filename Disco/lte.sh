#!/bin/sh
cd /data/ftp
insmod usbserial.ko 
insmod usb_wwan.ko
insmod option.ko
insmod crc-ccitt.ko
insmod slhc.ko
insmod ppp_generic.ko
insmod ppp_async.ko
insmod ppp_deflate.ko
insmod bsd_comp.ko
sleep 10
/data/ftp/usb_modeswitch -s 15 -I -J -c /data/ftp/usb_modeswitch.conf
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ftp
sleep 2
./pppd call lte
echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4' >/etc/resolv.conf
/data/ftp/glympse_gps.sh &
sleep 5
wget -qO - "http://user:password@dynupdate.no-ip.com/nic/update?hostname=my_host_name.zapto.org&myip=`ifconfig ppp0 |grep 'inet addr' |cut -d ':' -f 2 |cut -d ' ' -f 1`"
while true; do ./pppd 192.168.42.211:192.168.42.210 nodetach pty "nc -l -p 3333"; killall nc; done
