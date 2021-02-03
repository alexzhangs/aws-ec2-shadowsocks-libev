# aws-ec2-shadowsocks-libev

Install shadowsocks-libev server on AWS EC2 instance.

Tested with:

* [AWS Amazon Linux AMI](https://aws.amazon.com/amazon-linux-ami/)
* [AWS Amazon Linux 2 AMI](https://aws.amazon.com/amazon-linux-2/)
* [Shadowsocks-libev 3.2.0 for Linux](https://github.com/shadowsocks/shadowsocks-libev)

## Installation

Run below commands on the remote server.

```
git clone https://github.com/alexzhangs/aws-ec2-shadowsocks-libev

# run this under root
bash aws-ec2-shadowsocks-libev/install.sh

# see help
bash aws-ec2-shadowsocks-libev/install.sh -h
Usage: install.sh [-m ENCRYPTION_METHOD] [-t TIMEOUT] [-f true|false] [-s SERVER] [-p PORT]
OPTIONS
	[-m ENCRYPTION_METHOD]

	Encryption method, default is aes-256-cfb.

	[-t TIMEOUT]

	Connecting timeout after <N> seconds, default is 60.

	[-f true|false]

	Fast Open, default is false.

	[-s SERVER]

	IP address that Shadowsocks manager will listen on, default is 127.0.0.1.
	Use 0.0.0.0 instead of specific IP address to bind on public interface to eliminate
	the dependency. But be aware that the manager API is not protected.

	[-p PORT]

	Port that Shadowsocks manager will listen on, default is 6001.
	This port is used by multi-user API, is not for the Socks services.
	Don't confuse it with the Shadowsocks service ports.
```
    
## Add Shadowsocks users (ports)

There are two methods to do this.

1. Using config file

Edit `/etc/shadowsocks-libev/config.json`, add the `port/password` under the key `port_password`.

```
{
    "server": "0.0.0.0",
    ...
    "port_password": {
        "8381": "foobar1",
        "8382": "foobar2",
        "8383": "foobar3",
        "8384": "foobar4"
    }
}
```

Restart the Shadowsocks service to let the new added ports take effect.

```
service shadowsocks-libev-manager restart
```

1. Using multi-user API

See the [Manage Multiple Users](https://github.com/shadowsocks/shadowsocks/wiki/Manage-Multiple-Users) document.


NOTE: Remember to open all the used ports in EC2 instance's security group as inbound rules.

## Reference

* [shadowsocks-manager](https://github.com/alexzhangs/shadowsocks-manager)
* [aws-cfn-vpn](https://github.com/alexzhangs/aws-cfn-vpn)
* [Shadowsocks-libev 3.2.0 for Linux](https://github.com/shadowsocks/shadowsocks-libev)
