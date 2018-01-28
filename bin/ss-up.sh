#!/bin/bash

SOCKS_SERVER=$SERVER_IP # SOCKS 服务器的 IP 地址
# Setup the ipset
ipset -N chnroute hash:net maxelem 65536

for ip in $(cat '/root/bin/routing-table/cn_rules.conf'); do
  ipset add chnroute $ip
done

# 在nat表中新增一个链，名叫：SHADOWSOCKS
iptables -t nat -N SHADOWSOCKS

# Allow connection to the server
iptables -t nat -A SHADOWSOCKS -d $SOCKS_SERVER -j RETURN

# Allow connection to reserved networks
iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

# Allow connection to chinese IPs
iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set chnroute dst -j RETURN
# 如果你想对 icmp 协议也实现智能分流，可以加上下面这一条
# iptables -t nat -A SHADOWSOCKS -p icmp -m set --match-set chnroute dst -j RETURN

# Redirect to Shadowsocks
# 把1080改成你的shadowsocks本地端口
iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-port 1080
# 如果你想对 icmp 协议也实现智能分流，可以加上下面这一条
# iptables -t nat -A SHADOWSOCKS -p icmp -j REDIRECT --to-port 1080

# 将SHADOWSOCKS链中所有的规则追加到OUTPUT链中
iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS
# 如果你想对 icmp 协议也实现智能分流，可以加上下面这一条
# iptables -t nat -A OUTPUT -p icmp -j SHADOWSOCKS

# 如果你想让这台电脑作为局域网内其他设备的网关，让其他设备也能实现智能分流，可以加上下面的规则

# 内网流量流经 shadowsocks 规则链，把 192.168/16 替换成你的实际的内网网段
iptables -t nat -A PREROUTING -s 192.168/16 -j SHADOWSOCKS
# 内网流量源NAT
iptables -t nat -A POSTROUTING -s 192.168/16 -j MASQUERADE
