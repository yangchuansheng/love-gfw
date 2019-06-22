# `Linux` 和 `MacOS` 设备智能分流方案

![](./img/socialist.jpg) ![](./img/gfw.jpg)

通过路由器 360 度无痛爱国的方案已经层出不穷，然而我们不得不面对一个很现实的问题：**你不可能走到哪里都带着一个路由器！**

为了解决这个问题，本教程就诞生了，目标是手把手教你在不同操作系统上 360 度无死角自动翻越万里长城。:clap:

PS: 目前只能在 Linux 和 MacOS 系统上实现， Windows
 用户请绕行

## 本教程爱国方案的特点
放弃建立黑名单的方案吧，被墙的网站每天在大量增加，有限的人生不能在无穷的手工添加黑名单、重启设备中度过。

大道至简，一劳永逸！

+ 建立国内重要网站名单，在国内进行dns查询
+ 其他网站通过 `shadowsocks` 客户端向 `shadowsocks` 服务端进行 dns 查询
+ 国内或亚洲的 IP 流量走国内通道
+ 其他流量通过 `shadowsocks` 服务端转发

## 知识若不分享，实在没有意义

什么是圣人，圣人就是得到和付出比较均衡的人。天地生我，我敬天地；父母育我，我亦养父母；网上获得知识，也要在网上分享知识。于是，花了许多天，查资料，写教程，调试固件，不知不觉一天就过去了。

自由的感觉真好:　`youtube`, `hulu`, `twitter`, `facebook`, `google`...

本文档不涉及 `shadowsocks` 的原理及基础配置，如果你连这些基本的知识也没掌握，请左转绕道而行，了解这些基本的知识之后再来看本教程。

欢迎提 `Issues` 参与维护项目。

<br />

> 这里有两种思路可以实现全局智能分流，一种思路是通过防火墙策略，另一种思路是通过策略路由表。

## 通过防火墙策略实现

防火墙工具有很多种，我尝试过并且成功实现功能的有两种，一个是 `iptables`，另一个是 `nftables`。`iptables` 大家应该都比较熟悉，`nftables` 对于大多数人来说也许比较陌生，如果你想进一步了解，请参考 [Linux 首次引入 nftables，你可能会喜欢 nftables 的理由](http://blog.jobbole.com/59624/)

**遗憾的是，该方案并不适用于 MacOS 系统，如果你有什么好的建议，欢迎给我提供帮助。**

### 1. 通过 iptables 实现智能分流

这种方案的思路是使用 `ipset` 载入 chnroute 的 IP 列表并使用 `iptables` 实现带自动分流国内外流量的全局代理

+ [Linux 系统](./docs/iptables-linux.md)
+ MacOS 系统：暂无实现，与之类似的方案请参考 [一个基于 VirtualBox 和 openwrt 构建的项目, 旨在实现 macOS / Windows 平台的透明代理](https://github.com/icymind/VRouter)

### 2. 通过 nftables 实现智能分流

+ [Linux 系统](./docs/nftables-linux.md)
+ MacOS 系统：暂无实现

## 通过策略路由表实现

这种方案的大致思路是先启动一个本地 `socks` 代理，然后通过工具将 `socks` 代理伪装成 `vpn`，最后再通过策略路由进行分流。

有两种工具可以将 `socks` 代理伪装成 `vpn`。

### 1. 通过 badvpn 实现智能分流

主要介绍一下 `tun2socks`，它其实是 `badvpn` 的一个组成部分。

`tun2socks` 实现一种机制，它可以让你无需改动任何应用程序而完全透明地将数据用 `socks` 协议封装，转发给一个 `socks` 代理，然后由该代理程序负责与真实服务器之间转发应用数据。

使用代理有两种方式，一种是你自己显式配置代理，这样一来，数据离开你的主机时它的目标地址就是代理服务器，另一种是做透明代理，即在中途把原始数据重定向到一个应用程序，由该代理程序代理转发。

`tun2socks` 在第二种的基础上，完成了`socks` 协议的封装，并且实现该机制时使用了强大的 `tun` 网卡而不必再去配置复杂的 `iptables` 规则。

+ [Linux 系统](./docs/badvpn-linux.md)
+ MacOS 系统：暂时无法编译成功，如有人编译成功，望告知

### 2. 通过 gotun2socks 实现智能分流

`gotun2socks` 实际上是 `badvpn` 的 `go` 语言实现方式，而且更加智能化，它会在启动时自动帮你添加 tuntap 网卡，停止时自动删除该网卡，不需要我们手动添加删除。怎么样，是不是有点小激动呢？是不是从此爱上 go 语言了呢？:relieved:

+ [Linux 系统](./docs/gotun2socks-linux.md)
+ [MacOS 系统](./docs/gotun2socks-macos.md)

## 番外篇

虽然以上各种花式爱国方案都能实现全局智能分流，但对大多数人来说还是太复杂了，令人望而生畏。绝大多数人对于全局智能分流的需求不是很强烈，只需要让某些特殊的应用程序使用代理就行了。有的应用程序可以让你选择使用代理，但很多应用根本不提供这部分的配置。现在为了让一些原本逻辑没考虑/不使用/无法配置代理的软件流量经过代理走，只能通过 hook 的方式劫持系统调用。

利用 [Proxifier](https://www.proxifier.com/) 就可以实现此功能，在 Proxifier 的帮助下，即使你不懂任何网络原理，通过简单配置也可以轻松地玩转流量转发。并且相比于 VPN（虚拟专用网）全局代理，Proxifier 这种灵活配置还可以实现一些意想不到的功能，例如：监测某个应用的流量或是屏蔽广告等。当然至于最终如何使用，完全取决于您的想像力。

为了更好的使用 Proxifier，我们通过以下示意图来了解一下 Proxifier 工作的原理：

1. Proxifier 启动后接管系统内所有的网络请求连接；
2. 接管后的网络请求连接以 Proxifier 配置的规则处理；
3. Direct (直连) 直接访问外部网络；Proxy (代理) 将请求交给代理服务器处理后再连接到外网；Block (禁止) 则会拦截掉向外发送的请求。

<div align=center><img src="https://ws3.sinaimg.cn/large/006tNc79gy1fz0edczefvj30dp06xdg8.jpg"/></div>

需要说明的是，Proxifier 是收费的，也就几十块钱左右，大家最好还是支持正版。我这里也提供了一个 MacOS 破解版本：[Proxifier_2.22.1_xclient.info.dmg](https://www.lanzous.com/i2tv3je)。解压密码为：`xclient.info`，密钥在解压后的文本里。下面的使用教程针对的是 MacOS 用户，Windows 平台类似。

### 使用教程

接下来配置的三步顺序：

+ 代理服务器配置
+ 代理规则设置
+ 域名解析设置

① 打开软件点击 Proxies：

<div align=center><img width="400" src="https://ws1.sinaimg.cn/large/006tNc79gy1fz0f3d99hwj316a0u04d2.jpg"/></div>

+ 点击 “Add”
+ 输入本地 shadowshocks 的 ip（默认127.0.0.1）和端口（默认1080）
+ 选择 `SOCKS Versin 5`
+ OK

![](https://ws1.sinaimg.cn/large/006tNc79gy1fz0faoblsej30u00vdjvs.jpg)

**接下来的两步配置至关重要，配置错误可能导致代理失败或者循环代理！**

② 配置第二步

+ 点击 Rules
+ 选中 localhost,点击 Edit
+ Target hosts 处添加 shadowshocks 代理服务器的 IP 地址（以 123.123.123.123 示例）
+ Action选择Direct(直连)
+ OK

![](https://ws1.sinaimg.cn/large/006tNc79gy1fz0feaqxvcj30t60tuadn.jpg)

**注：此配置步骤允许发送到代理服务器的数据包通过，防止循环代理错误。**

配置后如图：

![](https://ws4.sinaimg.cn/large/006tNc79gy1fz0fhuwiqoj316u03a3zs.jpg)

③ 配置第三步

+ 点击 DNS
+ 选择第二个 Resolve hostnames through proxy（通过代理服务器解析域名）
+ OK

![](https://ws2.sinaimg.cn/large/006tNc79gy1fz0fnrzenij30vq0qggoz.jpg)

**如果你已经配置了无污染 DNS，这里可以直接选择 Detect DNS settings automatically，使用系统默认的 DNS。**

至此，代理已经配置完毕，接下来我给出一些具体使用场景的示例。平时工作中最常用的需要使用代理的工具就是 `git`，为了让 git 强制性使用代理，只需在 Proxifier 中创建一个代理规则：

+ 点击 Rules
+ 点击 Add
+ Name 字段填入 git
+ Applications 字段填入 `git-remote-https`
+ Action 选择 Proxy SOCKS5 127.0.0.1:1080

![](https://ws4.sinaimg.cn/large/006tNc79gy1fz0g2zxu4oj30t60tu41s.jpg)

如果你不知道 Applications 字段该写什么，我可以教你一个方法，在 git clone 的过程中通过下面的命令来寻找使用代理的进程：

```bash
$ sudo ps -ef|grep git

  501  5623     1   0  2Dec18 ??         0:00.89 /Applications/Atom.app/Contents/Frameworks/Squirrel.framework/Resources/ShipIt com.github.atom.ShipIt /Users/yangcs/Library/Caches/com.github.atom.ShipIt/ShipItState.plist
  501 77481 92668   0  5:14PM ttys002    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn git
  501 77184 62902   0  5:14PM ttys003    0:00.07 git clone https://github.com/kubernetes/kubernetes
  501 77185 77184   0  5:14PM ttys003    0:01.58 /usr/local/Cellar/git/2.18.0/libexec/git-core/git-remote-https origin https://github.com/kubernetes/kubernetes
  501 77189 77185   0  5:14PM ttys003    0:00.39 /usr/local/Cellar/git/2.18.0/libexec/git-core/git fetch-pack --stateless-rpc --stdin --lock-pack --thin --check-self-contained-and-connected --cloning https://github.com/kubernetes/kubernetes/
  501 77190 77189   0  5:14PM ttys003    0:01.52 /usr/local/Cellar/git/2.18.0/libexec/git-core/git index-pack --stdin -v --fix-thin --keep=fetch-pack 77189 on MacBookPro --check-self-contained-and-connected --pack_header=2,877904
```

很明显，`git-remote-https` 就是我们想找的进程，如果你还不放心，可以将 `git` 也加入 Applications 字段。

![](https://ws1.sinaimg.cn/large/006tNc79gy1fz0gesufy3j30t60tugox.jpg)

现在如果你通过 `git clone` 来拉取仓库，就可以看到详细的连接统计信息：

![](https://ws2.sinaimg.cn/large/006tNc79gy1fz0gjpd5pqj318b0u0ai6.jpg)

另外一个典型的使用场景就是 Docker。配置方法和 git 类似，我就不演示了，重点提醒一下 Applications 字段值是 `com.docker.vpnkit`。如果你不放心，可以使用通配符 `*docker*`。Target Hosts 字段填入 `gcr.io; *.docker.io`。

![](https://ws1.sinaimg.cn/large/006tNc79gy1fz0gscf7gxj30t60tugoz.jpg)

来，我们来 pull 一个传说中的无法使用代理拉取的 gcr.io 镜像，我就不信这个邪了：

![](https://ws4.sinaimg.cn/large/006tNc79gy1fz0gwgkw6bj31s807odkr.jpg)

![](https://ws2.sinaimg.cn/large/006tNc79gy1fz0gvtuns0j318b0u01a1.jpg)

怎么样，还有谁？！

其他还有一些迷之应用，比如 `brew`、`Slack` 都可以使用这个方法来强制使用代理，大家可以自己探索，再见！

## 版权

Copyright 2018 Ryan (yangchuansheng33@gmail.com)

MIT License，详情见 LICENSE 文件。
