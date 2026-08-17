#!/bin/bash
# proxywrap.sh - 通用包装器

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

# 根据命令类型注入代理
case "$1" in
    curl)
        if [ "$PROXY" != "None" ]; then
            exec curl -x "$PROXY" "${@:2}"
        else
            exec curl "${@:2}"
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
    *)
        if [ "$PROXY" != "None" ]; then
            export http_proxy="$PROXY"
            export https_proxy="$PROXY"
            export HTTP_PROXY="$PROXY"
            export HTTPS_PROXY="$PROXY"
        fi
        exec "$@"
        ;;
esac
