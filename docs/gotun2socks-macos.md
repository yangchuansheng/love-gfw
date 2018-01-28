# MacOS 系统通过 gotun2socks 实现智能分流

## 安装 go 语言

`homebrew` 是 `Mac` 系统下面目前使用最多的管理软件的工具，目前已支持 Go，可以通过命令直接安装 Go，为了以后方便，应该把 `git` `mercurial` 也安装上：

1. 安装 homebrew

```bash
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

2. 安装 go

```bash
$ brew update && brew upgrade
$ brew install go
$ brew install git
$ brew install mercurial #可选安装
```

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

```bash
$ brew install shadowsocks-libev
```

配置请参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AEshadowsocks-libev](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AEshadowsocks-libev)

**补充：MacOS 中可以通过 brew 来运行守护进程，命令以及参数如下**

```bash
# 列出当前运行的服务
$ sudo brew services list

dbus              stopped
pcap_dnsproxy     started root /Library/LaunchDaemons/homebrew.mxcl.pcap_dnsproxy.plist
shadowsocks-libev started root /Library/LaunchDaemons/homebrew.mxcl.shadowsocks-libev.plist

# 停止 shadowsocks-libev 服务
$ sudo brew services stop shadowsocks-libev

# 启动 shadowsocks-libev 服务
$ sudo brew services start shadowsocks-libev

# 重启 shadowsocks-libev 服务
$ sudo brew services  restart shadowsocks-libev
```

## 获取中国 IP 段

将以下命令写入脚本保存执行（假设保存在 `$HOME/bin/routing-table` 目录下）：

```bash
#!/bin/sh

wget -c http://ftp.apnic.net/stats/apnic/delegated-apnic-latest
cat delegated-apnic-latest | awk -F '|' '/CN/&&/ipv4/ {print $4 "/" 32-log($5)/log(2)}' | cat > $HOME/bin/routing-table/cn_rules.conf
```

## 配置智能 DNS 服务

参考 [https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AE%E6%99%BA%E8%83%BD-dns-%E6%9C%8D%E5%8A%A1](https://github.com/yangchuansheng/love-gfw/blob/master/docs/iptables-linux.md#%E9%85%8D%E7%BD%AE%E6%99%BA%E8%83%BD-dns-%E6%9C%8D%E5%8A%A1)

PS：MacOS 系统可以通过 brew 安装

```bash
$ brew install pcap_dnsproxy
```

## 配置路由表启动脚本

```bash
$ cat /usr/local/bin/start-socksfwd

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
ip route add "$i" via "$GATEWAY_IP"
done

# 将默认网关设为虚拟网卡的IP地址
route delete default
$GOPATH/bin/gotun2socks -tun-device "$TUN_NETWORK_DEV" -tun-address "$TUN_NETWORK_PREFIX.2" -tun-gw "$TUN_NETWORK_PREFIX.1" -local-socks-addr "127.0.0.1:$SOCKS_PORT"
route add default "$TUN_NETWORK_PREFIX.1"
```

## 配置路由表删除脚本

```bash
$ cat /usr/local/bin/stop-socksfwd

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
```

**启动流程为：**

+ 启动 shadowsocks 服务：

```bash
$ sudo brew services start shadowsocks-libev
```

当然这里不一定得用 `shadowsocks` 服务，只要是 `socks5` 协议都可以。

+ 启动 pcap_dnsproxy 服务

```bash
$ sudo brew services start pcap_dnsproxy
```

+ 添加路由表

```bash
$ sudo bash /usr/local/bin/start-socksfwd
```

**关闭流程为：**

+ 删除路由表

```bash
$ sudo bash /usr/local/bin/stop-socksfwd
```

+ 停止 shadowsocks 服务

```bash
$ sudo brew services stop shadowsocks-libev
```


