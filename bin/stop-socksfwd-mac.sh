#!/bin/bash

# SOCKS 服务器的 IP 地址
SOCKS_SERVER=47.52.201.34
# 本地SOCKS 服务器的端口
SOCKS_PORT=1080
# 家用网关（路由器）的 IP 地址，你也可以手动指定
# GATEWAY_IP=$(ip route|grep "default"|awk '{print $3}')
GATEWAY_IP=192.168.1.1
# 选一个不冲突的 tun 设备号
TUN_NETWORK_DEV=tun0
# 选一个不冲突的内网 IP 段的前缀
TUN_NETWORK_PREFIX=12.0.0

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
