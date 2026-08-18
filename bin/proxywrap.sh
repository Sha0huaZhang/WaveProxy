#!/bin/bash
# proxywrap.sh - 通用包装器
# 支持: curl, wget, git, wave, npm, yarn, pnpm, pip, pip3, poetry, 
#       docker, podman, apt, apt-get, yum, dnf, pacman, zypper, brew, port

# 显示帮助
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo -e "\033[35musage: \033[38;5;197mproxywrap <command> [args...]\033[0m"
    echo
    echo "proxywrap 1.0.0 🌊"
    echo "Auto-inject proxy into any command."
    echo
    echo -e "\033[35mSupported commands:\033[0m"
    echo "  \033[32mcurl\033[0m    -> -x \"\$PROXY\""
    echo "  \033[32mwget\033[0m    -> -e use_proxy=yes -e http_proxy=\"\$PROXY\""
    echo "  \033[32mgit\033[0m     -> -c http.proxy=\"\$PROXY\""
    echo "  \033[32mwave\033[0m    -> --proxy \"\$PROXY\""
    echo "  \033[32mbrew\033[0m, \033[32mport\033[0m, \033[32mnpm\033[0m, \033[32mpip\033[0m, \033[32mdocker\033[0m, ... -> http_proxy env"
    echo
    echo -e "\033[35mFlags:\033[0m"
    echo "  \033[32m-h, --help\033[0m          Show this help message and exit"
    echo
    echo "For more details, visit: https://proxy.macwave.org"
    exit 0
fi

# --- 处理 --help-all ---
if [[ "$1" == "--help-all" ]]; then
    echo -e "\033[35m==== proxywrap (auto-inject wrapper) ====\033[0m"
    # 复用 -h 的打印逻辑（直接调用自身 -h）
    $0 -h
    echo -e "\033[35m========================================\033[0m"
    echo
    echo -e "\033[35m==== waveproxy (proxy decision engine) ====\033[0m"
    waveproxy -h 2>/dev/null || echo "🌊 waveproxy command not found."
    echo -e "\033[35m==========================================\033[0m"
    echo
    echo -e "\033[35m==== proxydeploy (configuration management) ====\033[0m"
    proxydeploy -h 2>/dev/null || echo "🌊 proxydeploy command not found."
    exit 0
fi

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
PROXY=$(waveproxy query "$URL" 2>/dev/null || echo "None")

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
