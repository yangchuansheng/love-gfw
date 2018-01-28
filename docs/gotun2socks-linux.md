# Linux 系统通过 gotun2socks 实现智能分流

## 安装 go 语言

+ Archlinux

```bash
$ pacman -S go git
```

+ CentOS7

```bash
$ yum install -y golang git
```

+ Ubuntu

```bash
$ apt-get install python-software-properties
$ add-apt-repository ppa:gophers/go
$ apt-get update
$ apt-get install golang-stable git-core mercurial
```

其他发行版请参考 [安装 Go](https://github.com/astaxie/build-web-application-with-golang/blob/master/zh/01.1.md)

注意要将 `$GOPATH/bin` 加入 `$PATH` 环境变量，编辑 `/etc/profile`

```bash
$ vim /etc/profile 
```

加入以下内容

```bash
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH
```

然后执行以下命令使环境变量生效

```bash
$ source /etc/profile
```

## 安装 gotun2socks

```bash
$ go get github.com/yinghuocho/gotun2socks/bin/gotun2socks
```

这个命令会将 [https://github.com/yinghuocho/gotun2socks](https://github.com/yinghuocho/gotun2socks) 仓库克隆下来，并且将 `bin/gotun2socks/main.go` 编译成可执行二进制文件放到 `$GOPATH/bin` 目录下，现在你应该理解为什么要将 `$GOPATH/bin` 加入 `$PATH` 环境变量了吧。

## 安装 shadowsocks-libev

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E5%AE%89%E8%A3%85%E7%9B%B8%E5%85%B3%E8%BD%AF%E4%BB%B6](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E5%AE%89%E8%A3%85%E7%9B%B8%E5%85%B3%E8%BD%AF%E4%BB%B6)

## 配置 shadowsocks-libev

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AEshadowsocks-libev](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AEshadowsocks-libev)

## 获取中国 IP 段

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E8%8E%B7%E5%8F%96%E4%B8%AD%E5%9B%BDip%E6%AE%B5](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E8%8E%B7%E5%8F%96%E4%B8%AD%E5%9B%BDip%E6%AE%B5)

## 配置智能 DNS 服务

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AE%E6%99%BA%E8%83%BD-dns-%E6%9C%8D%E5%8A%A1](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AE%E6%99%BA%E8%83%BD-dns-%E6%9C%8D%E5%8A%A1)

## 配置路由表启动脚本

```bash
$ cat /usr/local/bin/start-socksfwd

#!/bin/bash

ip route add "$SOCKS_SERVER" via "$GATEWAY_IP"

# 特殊ip段走家用网关（路由器）的 IP 地址（如局域网联机）
# ip route add "192.168.0.0/16" via "$GATEWAY_IP"
# ip route add "10.8.0.0/16" via "$GATEWAY_IP"

# 国内网段走家用网关（路由器）的 IP 地址
for i in $(cat /root/bin/routing-table/cn_rules.conf)
do
ip route add "$i" via "$GATEWAY_IP"
done

# 将默认网关设为虚拟网卡的IP地址
ip route del default
ip route add 0.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
ip route add 128.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
```

## 配置路由表删除脚本

```bash
$ cat /usr/local/bin/stop-socksfwd

#!/bin/bash

ip route del 128.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
ip route del 0.0.0.0/1 via "$TUN_NETWORK_PREFIX.1"
ip route add default via "$GATEWAY_IP"

for i in $(cat /root/bin/routing-table/cn_rules.conf)
do
ip route del "$i" via "$GATEWAY_IP"
done

# ip route del "192.168.0.0/16" via "$GATEWAY_IP"
# ip route del "10.8.0.0/16" via "$GATEWAY_IP"
ip route del "$SOCKS_SERVER" via "$GATEWAY_IP"
```

## 将启动和删除脚本加入到 systemd 守护进程中

```bash
$ cat /etc/systemd/system/socksfwd.service

[Unit]

Description=Transparent SOCKS5 forwarding

After=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/socksfwd
ExecStart=/usr/local/bin/gotun2socks -tun-device "$TUN_NETWORK_DEV" -tun-address "$TUN_NETWORK_PREFIX.2" -tun-gw "$TUN_NETWORK_PREFIX.1" -local-socks-addr "127.0.0.1:$SOCKS_PORT"
ExecStartPost=/usr/local/bin/start-socksfwd
ExecStopPost=/usr/local/bin/stop-socksfwd
LimitNOFILE=1048576

[Install]

WantedBy=multi-user.target
```

```bash
$ cat /etc/socksfwd

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