## 安装 badvpn

+ Archlinux

```bash
$ pacman -S badvpn
```

其他发行版请参考 [https://github.com/ambrop72/badvpn/wiki/Tun2socks](https://github.com/ambrop72/badvpn/wiki/Tun2socks)

## 安装 shadowsocks-libev

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E5%AE%89%E8%A3%85%E7%9B%B8%E5%85%B3%E8%BD%AF%E4%BB%B6](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E5%AE%89%E8%A3%85%E7%9B%B8%E5%85%B3%E8%BD%AF%E4%BB%B6)

## 配置 shadowsocks-libev

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AEshadowsocks-libev](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AEshadowsocks-libev)

## 获取中国 IP 段

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E8%8E%B7%E5%8F%96%E4%B8%AD%E5%9B%BDip%E6%AE%B5](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E8%8E%B7%E5%8F%96%E4%B8%AD%E5%9B%BDip%E6%AE%B5)

## 配置智能 DNS 服务

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AE%E6%99%BA%E8%83%BD-dns-%E6%9C%8D%E5%8A%A1](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AE%E6%99%BA%E8%83%BD-dns-%E6%9C%8D%E5%8A%A1)

## 写路由表启动和终止脚本

```bash
$ cat /usr/local/bin/socksfwd

#!/bin/bash
SOCKS_SERVER=$SERVER_IP # SOCKS 服务器的 IP 地址
SOCKS_PORT=1080 # 本地SOCKS 服务器的端口
GATEWAY_IP=$(ip route|grep "default"|awk '{print $3}') # 家用网关（路由器）的 IP 地址，你也可以手动指定
TUN_NETWORK_DEV=tun0 # 选一个不冲突的 tun 设备号
TUN_NETWORK_PREFIX=12.0.0 # 选一个不冲突的内网 IP 段的前缀


start_fwd() {
ip tuntap del dev "$TUN_NETWORK_DEV" mode tun
# 添加虚拟网卡
ip tuntap add dev "$TUN_NETWORK_DEV" mode tun
# 给虚拟网卡绑定IP地址
ip addr add "$TUN_NETWORK_PREFIX.1/24" dev "$TUN_NETWORK_DEV"
# 启动虚拟网卡
ip link set "$TUN_NETWORK_DEV" up
ip route add "$SOCKS_SERVER" via "$GATEWAY_IP"
# 特殊ip段走家用网关（路由器）的 IP 地址（如局域网联机）
# ip route add "172.16.39.0/24" via "$GATEWAY_IP"
# 国内网段走家用网关（路由器）的 IP 地址
for i in $(cat /root/bin/routing-table/cn_rules.conf)
do
ip route add "$i" via "$GATEWAY_IP"
done
# 将默认网关设为虚拟网卡的IP地址
ip route del default via "$GATEWAY_IP"
ip route add 0.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
ip route add 128.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
# 将socks5转为vpn
badvpn-tun2socks --tundev "$TUN_NETWORK_DEV" --netif-ipaddr "$TUN_NETWORK_PREFIX.2" --netif-netmask 255.255.255.0 --socks-server-addr "127.0.0.1:$SOCKS_PORT"
TUN2SOCKS_PID="$!"
}


stop_fwd() {
ip route del 128.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
ip route del 0.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
for i in $(cat /root/bin/routing-table/cn_rules.conf)
do
ip route del "$i" via "$GATEWAY_IP"
done
# ip route del "172.16.39.0/24" via "$GATEWAY_IP"
ip route del "$SOCKS_SERVER" via "$GATEWAY_IP"
ip route add default via "$GATEWAY_IP"
ip link set "$TUN_NETWORK_DEV" down
ip addr del "$TUN_NETWORK_PREFIX.1/24" dev "$TUN_NETWORK_DEV"
ip tuntap del dev "$TUN_NETWORK_DEV" mode tun
}



start_fwd
trap stop_fwd INT TERM
wait "$TUN2SOCKS_PID"
```

```bash
$ cat /etc/systemd/system/socksfwd.service

[Unit]

Description=Transparent SOCKS5 forwarding

After=network-online.target

[Service]

Type=simple

ExecStart=/usr/local/bin/socksfwd

LimitNOFILE=1048576


[Install]

WantedBy=multi-user.target
```

启动服务

```bash
$ systemctl start socksfwd
```

设置成开机自启

```bash
$ systemctl enable socksfwd
```

## 打开流量转发

```bash
$ cat /etc/sysctl.d/30-ipforward.conf

...
...
net.ipv4.ip_forward=1

net.ipv6.conf.all.forwarding = 1

net.ipv4.tcp_syn_retries = 5

net.ipv4.tcp_synack_retries = 5
```

编辑完成后，执行以下命令使变动立即生效

```bash
$ sysctl -p
```

如果局域网内的其他设备也想实现智能分流，请将网关和 DNS 均设置为这台电脑的 IP。