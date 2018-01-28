## 安装相关软件

+ Archlinux

```bash
$ pacman -S shadowsocks-libev ipset
```

+ Ubuntu

```bash
$ apt update
$ apt install shadowsocks-libev ipset
```

+ CentOS7

```bash
$ wget https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo -O /etc/yum.repos.d/shadowsocks-epel-7.repo
$ yum clean all
$ yum repolist
$ yum install -y shadowsocks-libev ipset
```

其他发行版请参考 [https://github.com/shadowsocks/shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)

## 配置shadowsocks-libev

假设shadowsocks配置文件为/etc/shadowsocks.json，配置文件格式如下：

```bash
{
"server":$SERVER_HOST,
"server_port":$SERVER_PORT,
"local_address":"0.0.0.0",
"local_port":1080,
"password":"123456789",
"timeout":300,
"method":"chacha20",
"fast_open":true,
"workers":1
}
```

参数含义我就不解释了，这属于 shadowsocks 的内容范畴，不然又要长篇大论了 :smile:

## 获取中国IP段

将以下命令写入脚本保存执行（假设保存在 `/root/bin/routing-table/` 目录下）：

```bash
$ cat /root/bin/routing-table/get_china_ip.sh

#!/bin/sh
wget -c http://ftp.apnic.net/stats/apnic/delegated-apnic-latest
cat delegated-apnic-latest | awk -F '|' '/CN/&&/ipv4/ {print $4 "/" 32-log($5)/log(2)}' | cat > /root/bin/routing-table/cn_rules.conf
```

## 创建启动和关闭脚本

```bash
$ cat /root/bin/shadowsocks/ss-up.sh

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
```

这是在启动 `shadowsocks` 之前执行的脚本，用来设置 `iptables` 规则，对全局应用代理并将 `chnroute` 导入 `ipset` 来实现自动分流。注意要把服务器 IP 和本地端口相关的代码全部替换成你自己的。

因为 `cn_rules.conf` 是一个 IP 段列表，而中国持有的 IP 数量上还是比较大的，所以如果使用 `hash:ip` 来导入的话会使内存溢出，但是你也不能尝试把整个列表导入 iptables。虽然导入 iptables 不会导致内存溢出，但是 iptables 是线性查表，即使你全部导入进去，也会因为低下的性能而抓狂。所以要使用 `hash:net`。

然后再创建 `/root/bin/shadowsocks/ss-down.sh`, 这是用来清除上述规则的脚本，比较简单

```bash
#!/bin/bash

# iptables -t nat -D OUTPUT -p icmp -j SHADOWSOCKS
iptables -t nat -D OUTPUT -p tcp -j SHADOWSOCKS
iptables -t nat -F SHADOWSOCKS
iptables -t nat -X SHADOWSOCKS
ipset destroy chnroute
```

接着执行

```bash
$ chmod +x ss-up.sh
$ chmod +x ss-down.sh
```

