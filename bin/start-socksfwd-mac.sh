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

route add "$SOCKS_SERVER" "$GATEWAY_IP"

# 特殊ip段走家用网关（路由器）的 IP 地址（如局域网联机）
# route add "192.168.0.0/16" "$GATEWAY_IP"
# route add "10.8.0.0/16" "$GATEWAY_IP"

# 国内网段走家用网关（路由器）的 IP 地址
for i in $(cat $HOME/bin/routing-table/cn_rules.conf)
do
route add "$i" "$GATEWAY_IP"
done

# 将默认网关设为虚拟网卡的IP地址
route delete default
$GOPATH/bin/gotun2socks -tun-device "$TUN_NETWORK_DEV" -tun-address "$TUN_NETWORK_PREFIX.2" -tun-gw "$TUN_NETWORK_PREFIX.1" -local-socks-addr "127.0.0.1:$SOCKS_PORT"
route add default "$TUN_NETWORK_PREFIX.1"
