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