#!/bin/bash

usage () {
    printf "Usage: ${0##*/} [-s SERVER] [-m ENCRYPTION_METHOD] [-t TIMEOUT] [-f true|false]\n"
    printf "OPTIONS\n"
    printf "\t[-s SERVER]\n\n"
    printf "\tServer IP to listen on, default is 0.0.0.0.\n\n"
    printf "\t[-m ENCRYPTION_METHOD]\n\n"
    printf "\tEncryption method, default is aes-256-cfb.\n\n"
    printf "\t[-t TIMEOUT]\n\n"
    printf "\tConnecting timeout after <N> seconds, default is 60.\n\n"
    printf "\t[-f true|false]\n\n"
    printf "\tFast Open, default is false.\n\n"
    exit 255
}

while getopts s:m:t:f:h opt; do
    case $opt in
        s)
            SERVER=$OPTARG
            ;;
        m)
            ENCRYPTION_METHOD=$OPTARG
            ;;
        t)
            TIMEOUT=$OPTARG
            ;;
        f)
            FAST_OPEN=$OPTARG
            ;;
        *|h)
            usage
            ;;
    esac
done

[[ -z $SERVER ]] && SERVER="0.0.0.0"
[[ -z $ENCRYPTION_METHOD ]] && ENCRYPTION_METHOD="aes-256-cfb"
[[ -z $TIMEOUT ]] && TIMEOUT=60
[[ -z $FAST_OPEN ]] && FAST_OPEN="false"

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
    cp -a ${0%/*}/conf/librehat-shadowsocks-epel-6.repo /etc/yum.repos.d/
    return $?
}


install_remote_repo || install_local_repo || exit $?

yum update -y || exit $?
yum install -y --enablerepo=librehat-shadowsocks shadowsocks-libev || exit $?

# config.json
cp -a ${0%/*}/conf/config.json /etc/shadowsocks-libev/config.json || exit $?
sed -i "s/<SERVER>/$SERVER" /etc/shadowsocks/config.json || exit $?
sed -i "s/<ENCRYPTION_METHOD>/$ENCRYPTION_METHOD/" /etc/shadowsocks/config.json || exit $?
sed -i "s/<TIMEOUT>/$TIMEOUT" /etc/shadowsocks/config.json || exit $?
sed -i "s/<FAST_OPEN>/$FAST_OPEN" /etc/shadowsocks/config.json || exit $?

# shadowsocks-libev-manager
cp -a ${0%/*}/shadowsocks-libev-manager /etc/init.d/shadowsocks-libev-manager || exit $?

# service
service shadowsocks-libev-manager restart || exit $?
chkconfig shadowsocks-libev-manager on || exit $?

exit
