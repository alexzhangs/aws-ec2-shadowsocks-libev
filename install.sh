#!/bin/bash

# Exit on any error
set -o pipefail -e

function usage () {
    printf "Usage: ${0##*/} [-m ENCRYPTION_METHOD] [-t TIMEOUT] [-f true|false] [-s SERVER] [-p PORT]\n"
    printf "OPTIONS\n"
    printf "\t[-m ENCRYPTION_METHOD]\n\n"
    printf "\tEncryption method, default is aes-256-cfb.\n\n"
    printf "\t[-t TIMEOUT]\n\n"
    printf "\tConnecting timeout after <N> seconds, default is 60.\n\n"
    printf "\t[-f true|false]\n\n"
    printf "\tFast Open, default is false.\n\n"
    printf "\t[-s SERVER]\n\n"
    printf "\tIP address that Shadowsocks manager will listen on, default is 127.0.0.1.\n"
    printf "\tUse 0.0.0.0 instead of specific IP address to bind on public interface to eliminate\n"
    printf "\tthe dependency. Bu be aware that the manager API is not protected.\n\n"
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

function if-yum-repo-exsit () {
    # Usage: if-yum-repo-exist <repo>; echo $?
    [[ "$(yum repolist "${1:?}" | awk 'END {print $NF}')" > 0 ]]
}

function amazon-linux-extra-safe () {
    repo=${1:?}
    if type amazon-linux-extras >/dev/null 2>&1; then
        if ! if-yum-repo-exist "$repo"; then
            # Amazon Linux 2 AMI needs this
            echo "installing repo: $repo ..."
            amazon-linux-extras install -y "$repo"
        else
            echo "$repo: not found the repo, abort." >&2
            exit 255
        fi
    else
        echo 'amazon-linux-extra: not found the command, continue' >&2
    fi
}

# epel
amazon-linux-extra-safe epel

function install_remote_repo() {
    local url ret=0
    for url in "${REPO_URLS[@]}"; do
        curl -v -s -o /etc/yum.repos.d/"$(basename "$url")" "$url"
        ret=$((ret + $?))
    done
    return $ret
}

function install_local_repo() {
    find $WORK_DIR/conf -name '*.repo' \
         | xargs -I {} cp -a {} /etc/yum.repos.d/
}

echo 'installing yum repo for shadowsocks ...'
install_remote_repo || install_local_repo

echo 'installing shadowsocks-libev ...'
yum install -y shadowsocks-libev \
    --enablerepo=epel --enablerepo=copr:copr.fedorainfracloud.org:librehat:shadowsocks

# config.json
echo 'installing /etc/shadowsocks-libev/config.json ...'
cp -a $WORK_DIR/conf/config.json /etc/shadowsocks-libev/config.json
sed -e "s/<ENCRYPTION_METHOD>/$ENCRYPTION_METHOD/" \
    -e "s/<TIMEOUT>/$TIMEOUT/" \
    -e "s/<FAST_OPEN>/$FAST_OPEN/" \
    -i /etc/shadowsocks-libev/config.json

# shadowsocks-libev-manager
echo 'installing /etc/init.d/shadowsocks-libev-manager ...'
cp -a $WORK_DIR/shadowsocks-libev-manager /etc/init.d/shadowsocks-libev-manager
sed -e "s/SSM_SERVER=.*/SSM_SERVER=$SERVER/" \
    -e "s/SSM_PORT=.*/SSM_PORT=$PORT/" \
    -i /etc/init.d/shadowsocks-libev-manager
chmod 755 /etc/init.d/shadowsocks-libev-manager

function symbol-link-try () {
    # Usage: symbol-link-try TARGET1 [TARGET2 ...] LINK_NAME
    [[ $# -lt 2 ]] && return 255
    local link_name=${!#}  # get the last argument
    if [[ ! -f $link_name ]]; then
        local target
        for target in "${@1:$#-1}"; do  # remove the last argument
            if [[ -f $target ]]; then
                echo "linking $target to $link_name ..."
                ln -s "$target" "$link_name"
                break
            fi
        done
    fi
}

# patch for Amazon Linux 2 AMI, on 2021-02-03
# defect: Starting shadowsocks-manager: /usr/bin/ss-manager: error while loading shared libraries: libsodium.so.13: cannot open shared object file: No such file or directory
symbol-link-try /usr/lib64/libsodium.so.23.3.0 /usr/lib64/libsodium.so /usr/lib64/libsodium.so.13

# patch for Amazon Linux 2 AMI, on 2021-02-03
# defect: Starting shadowsocks-manager: /usr/bin/ss-manager: error while loading shared libraries: libpcre.so.0: cannot open shared object file: No such file or directory
symbol-link-try /usr/lib64/libpcre.so.1.2.0 /usr/lib64/libpcre.so /usr/lib64/libpcre.so.0

echo 'updating chkconfig ...'
chkconfig --add shadowsocks-libev-manager

echo 'restarting service ...'
service shadowsocks-libev-manager restart

exit
