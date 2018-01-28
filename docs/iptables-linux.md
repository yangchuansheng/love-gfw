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

参数含义我就不解释了，这属于 shadowsocks 的内容范畴，不然又要长篇大论了:sun_with_face: