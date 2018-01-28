#!/bin/bash

route delete default
route add default "$GATEWAY_IP"

for i in $(cat $HOME/bin/routing-table/cn_rules.conf)
do
route delete "$i" "$GATEWAY_IP"
done

# route delete "192.168.0.0/16" "$GATEWAY_IP"
# route delete "10.8.0.0/16" "$GATEWAY_IP"
route delete "$SOCKS_SERVER" "$GATEWAY_IP"

TUN2SOCKS_PID=$(ps aux|grep tun2socks|egrep -v "grep"|awk '{print $2}')
kill -9 $TUN2SOCKS_PID
