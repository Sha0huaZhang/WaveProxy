#!/bin/bash
# proxywrap.sh - 通用包装器
# 支持: curl, wget, git, wave, npm, yarn, pnpm, pip, pip3, poetry, 
#       docker, podman, apt, apt-get, yum, dnf, pacman, zypper, brew, port

# 从参数里找 URL
URL=""
for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]]; then
        URL="$arg"
    fi
done

# 如果没找到 URL，直接执行原命令
if [ -z "$URL" ]; then
    exec "$@"
fi

# 获取代理（返回 "代理地址" 或 None）
PROXY=$(waveproxy.py query "$URL" 2>/dev/null || echo "None")

# === 显式参数类（需要 -x / --proxy 等参数） ===
case "$1" in
    curl)
        if [ "$PROXY" != "None" ]; then
            exec curl -x "$PROXY" "${@:2}"
        else
            exec curl "${@:2}"
        fi
        ;;
    wget)
        if [ "$PROXY" != "None" ]; then
            exec wget -e use_proxy=yes -e http_proxy="$PROXY" "${@:2}"
        else
            exec wget "${@:2}"
        fi
        ;;
    git)
        if [ "$PROXY" != "None" ]; then
            exec git -c http.proxy="$PROXY" "${@:2}"
        else
            exec git "${@:2}"
        fi
        ;;
    wave)
        if [ "$PROXY" != "None" ]; then
            exec wave "${@:2}" --proxy "$PROXY"
        else
            exec wave "${@:2}"
        fi
        ;;
    # === 环境变量类（设置 http_proxy 即可） ===
    brew|port|npm|yarn|pnpm|pip|pip3|poetry|docker|podman|apt|apt-get|yum|dnf|pacman|zypper)
        if [ "$PROXY" != "None" ]; then
            export http_proxy="$PROXY"
            export https_proxy="$PROXY"
            export HTTP_PROXY="$PROXY"
            export HTTPS_PROXY="$PROXY"
            export all_proxy="$PROXY"
            export ALL_PROXY="$PROXY"
        fi
        exec "$@"
        ;;
    # === 默认：走环境变量 ===
    *)
        if [ "$PROXY" != "None" ]; then
            export http_proxy="$PROXY"
            export https_proxy="$PROXY"
            export HTTP_PROXY="$PROXY"
            export HTTPS_PROXY="$PROXY"
            export all_proxy="$PROXY"
            export ALL_PROXY="$PROXY"
        fi
        exec "$@"
        ;;
esac
