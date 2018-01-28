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

## 配置ss-redir服务

首先，默认的 `ss-local` 并不能用来作为 `iptables` 流量转发的目标，因为它是 `socks5` 代理而非透明代理。我们至少要把 systemd 执行的程序改成 `ss-redir`。其次，上述两个脚本还不能自动执行，必须让 systemd 分别在启动 `shadowsocks` 之前和关闭之后将脚本执行，这样才能自动配置好 iptables 规则。

```bash
$ cat /usr/lib/systemd/system/shadowsocks-libev@.service

[Unit]
Description=Shadowsocks-Libev Client Service
After=network.target

[Service]
User=root
CapabilityBoundingSet=~CAP_SYS_ADMIN
ExecStart=
ExecStartPre=/root/bin/shadowsocks/ss-up.sh
ExecStart=/usr/bin/ss-redir -u -c /etc/%i.json
ExecStopPost=/root/bin/shadowsocks/ss-down.sh

[Install]
WantedBy=multi-user.target
```

然后启动服务

```bash
$ systemctl start shadowsocks-libev@shadowsocks
```

设置成开机自启

```bash
$ systemctl enable shadowsocks-libev@shadowsocks
```

## 配置智能 DNS 服务

完成了以上工作之后是不是就可以实现全局科学上网了呢？答案是否定的，我们还有最后一项工作需要完成，那就是解决 `DNS` 污染问题。如果你不知道什么是 `DNS` 污染，我可以简单地给你普及一下：

> `DNS` 污染是一种让一般用户由于得到虚假目标主机 `IP` 而不能与其通信的方法，是一种 DNS 缓存投毒攻击（DNS cache poisoning）。其工作方式是：由于通常的 `DNS` 查询没有任何认证机制，而且 DNS 查询通常基于的 `UDP` 是无连接不可靠的协议，因此 DNS 的查询非常容易被篡改，通过对 `UDP` 端口 53 上的 DNS 查询进行入侵检测，一经发现与关键词相匹配的请求则立即伪装成目标域名的解析服务器（NS，Name Server）给查询者返回虚假结果。

`DNS` 污染症状：目前一些被禁止访问的网站很多就是通过 `DNS` 污染来实现的，例如 `YouTube`、`Facebook` 等网站。

**应对dns污染的方法**

+ 对于 DNS 污染，可以说，个人用户很难单单靠设置解决，通常可以使用 `VPN` 或者域名远程解析的方法解决，但这大多需要购买付费的 `VPN` 或 `SSH` 等。<br />
+ 修改 `Hosts` 的方法，手动设置域名正确的 IP 地址。<br />
+ dns 加密解析：[DNSCrypt](https://dnscrypt.org/)
+ 忽略 DNS 投毒污染小工具：[Pcap_DNSProxy](https://github.com/chengr28/Pcap_DNSProxy)

我们选择用 `Pcap_DNSProxy` 来解决这个问题，以前用的是 `Pdnsd` + `Dnsmasq` 组合， 后来发现 TCP 请求效率太低加上家里网络与那些国外的 DNS 丢包实在是严重， 所以打算用 `Pcap_DNSProxy` 代替 `Pdnsd`。

关于 Pcap_DNSProxy 的详细介绍，可以参考: [https://github.com/chengr28/Pcap_DNSProxy](https://github.com/chengr28/Pcap_DNSProxy)<br />
安装过程可以参考： [https://github.com/chengr28/Pcap_DNSProxy/blob/master/Documents/ReadMe_Linux.zh-Hans.txt](https://github.com/chengr28/Pcap_DNSProxy/blob/master/Documents/ReadMe_Linux.zh-Hans.txt)<br /> 
更详细的使用说明可以参考： [https://github.com/chengr28/Pcap_DNSProxy/blob/master/Documents/ReadMe.zh-Hans.txt](https://github.com/chengr28/Pcap_DNSProxy/blob/master/Documents/ReadMe.zh-Hans.txt)

**这里主要重点强调一些需要注意的配置项：**

+ `DNS` - 境外域名解析参数区域（这是最关键的一项配置）

```bash
[DNS]
# 这里一定要填 IPv4 + TCP！！！表示只使用 TCP 协议向境外远程 DNS 服务器发出请求
Outgoing Protocol = IPv4 + TCP
# 建议当系统使用全局代理功能时启用，程序将除境内服务器外的所有请求直接交给系统而不作任何过滤等处理，系统会将请求自动发往远程服务器进行解析
Direct Request = IPv4
...
...
```

+ `Local DNS` - 境内域名解析参数区域

```bash
[Local DNS]
# 发送请求到境内 DNS 服务器时所使用的协议
Local Protocol = IPv4 + UDP
...
...
```

+ `Addresses` - 普通模式地址区域

```bash
[Addresses]
...
...
# IPv4 主要境外 DNS 服务器地址
IPv4 Main DNS Address = 8.8.4.4:53
# IPv4 备用境外 DNS 服务器地址
IPv4 Alternate DNS Address = 8.8.8.8:53|208.67.220.220:443|208.67.222.222:5353
# IPv4 主要境内 DNS 服务器地址，用于境内域名解析，推荐使用 onedns
IPv4 Local Main DNS Address = 112.124.47.27:53
# IPv4 备用境内 DNS 服务器地址，用于境内域名解析
IPv4 Local Alternate DNS Address = 114.215.126.16:53
...
...
```

配置好 DNS 服务之后将系统的 `DNS IP` 设置为 `127.0.0.1` 就可以了。

如果局域网内的其他设备也想实现智能分流，请将网关和 DNS 均设置为这台电脑的 IP。
