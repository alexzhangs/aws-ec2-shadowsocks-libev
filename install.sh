#!/bin/bash

# Exit on any error
set -o pipefail -e

usage () {
    printf "Usage: ${0##*/} [-m ENCRYPTION_METHOD] [-t TIMEOUT] [-f true|false] [-s SERVER] [-p PORT]\n"
    printf "OPTIONS\n"
    printf "\t[-m ENCRYPTION_METHOD]\n\n"
    printf "\tEncryption method, default is aes-256-cfb.\n\n"
    printf "\t[-t TIMEOUT]\n\n"
    printf "\tConnecting timeout after <N> seconds, default is 60.\n\n"
    printf "\t[-f true|false]\n\n"
    printf "\tFast Open, default is false.\n\n"
    printf "\t[-s SERVER]\n\n"
    printf "\tIP address that Shadowsocks manager will listen on, default is 127.0.0.1.\n\n"
    printf "\t[-p PORT]\n\n"
    printf "\tPort that Shadowsocks manager will listen on, default is 6001.\n\n"
    exit 255
}

while getopts m:t:f:s:p::h opt; do
    case $opt in
        m)
            ENCRYPTION_METHOD=$OPTARG
            ;;
        t)
            TIMEOUT=$OPTARG
            ;;
        f)
            FAST_OPEN=$OPTARG
            ;;
        s)
            SERVER=$OPTARG
            ;;
        p)
            PORT=$OPTARG
            ;;
        *|h)
            usage
            ;;
    esac
done

WORK_DIR=$(cd "$(dirname "$0")"; pwd)

[[ -z $ENCRYPTION_METHOD ]] && ENCRYPTION_METHOD="aes-256-cfb"
[[ -z $TIMEOUT ]] && TIMEOUT=60
[[ -z $FAST_OPEN ]] && FAST_OPEN="false"
[[ -z $SERVER ]] && SERVER="127.0.0.1"
[[ -z $PORT ]] && PORT=6001

REPO_URLS=(
    'https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-6/librehat-shadowsocks-epel-6.repo'
)

function install_remote_repo() {
    local url
    for url in "${REPO_URLS[@]}"; do
        curl -v -s -o /etc/yum.repos.d/librehat-shadowsocks-epel-6.repo "$url"
        [[ $? -eq 0 ]] && return
    done
    return 255
}

function install_local_repo() {
    cp -a $WORK_DIR/conf/librehat-shadowsocks-epel-6.repo /etc/yum.repos.d/
    return $?
}

# yum repo
install_remote_repo || install_local_repo

# shadowsocks-libev
yum-config-manager --enable epel --enable librehat-shadowsocks
yum install -y shadowsocks-libev

# config.json
cp -a $WORK_DIR/conf/config.json /etc/shadowsocks-libev/config.json
sed -e "s/<ENCRYPTION_METHOD>/$ENCRYPTION_METHOD/" \
    -e "s/<TIMEOUT>/$TIMEOUT/" \
    -e "s/<FAST_OPEN>/$FAST_OPEN/" \
    -i /etc/shadowsocks-libev/config.json

# shadowsocks-libev-manager
cp -a $WORK_DIR/shadowsocks-libev-manager /etc/init.d/shadowsocks-libev-manager
sed -e "s/SSM_SERVER=.*/SSM_SERVER=$SERVER/" \
    -e "s/SSM_PORT=.*/SSM_PORT=$PORT/" \
    -i /etc/init.d/shadowsocks-libev-manager
chmod 755 /etc/init.d/shadowsocks-libev-manager

# service
chkconfig --add shadowsocks-libev-manager
service shadowsocks-libev-manager restart

exit
