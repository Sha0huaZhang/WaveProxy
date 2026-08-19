#!/bin/bash
# proxywrap.sh - 通用包装器
# 支持: curl, wget, git, wave, npm, yarn, pnpm, pip, pip3, poetry, 
#       docker, podman, apt, apt-get, yum, dnf, pacman, zypper, brew, port

# ================== 颜色变量定义 ==================
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'
NC='\033[0m'  # No Color
# =================================================

# 显示帮助（用 printf 确保颜色渲染）
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    printf "${MAGENTA}usage: ${BOLD}proxywrap <command> [args...]${NC}\n"
    printf "\n"
    printf "proxywrap 1.0.0 🌊\n"
    printf "Auto-inject proxy into any command.\n"
    printf "\n"
    printf "${MAGENTA}Supported commands:${NC}\n"
    printf "  ${GREEN}curl${NC}    -> -x \"\$PROXY\"\n"
    printf "  ${GREEN}wget${NC}    -> -e use_proxy=yes -e http_proxy=\"\$PROXY\"\n"
    printf "  ${GREEN}git${NC}     -> -c http.proxy=\"\$PROXY\"\n"
    printf "  ${GREEN}wave${NC}    -> --proxy \"\$PROXY\"\n"
    printf "  ${GREEN}brew${NC}, ${GREEN}port${NC}, ${GREEN}npm${NC}, ${GREEN}pip${NC}, ${GREEN}docker${NC}, ... -> http_proxy env\n"
    printf "\n"
    printf "${MAGENTA}Flags:${NC}\n"
    printf "  ${GREEN}-h, --help${NC}          Show this help message and exit\n"
    printf "\n"
    printf "For more details, visit: https://proxy.macwave.org\n"
    exit 0
fi

# --- 处理 --help-all ---
if [[ "$1" == "--help-all" ]]; then
    printf "${MAGENTA}==== proxywrap (auto-inject wrapper) ====${NC}\n"
    # 复用 -h 的打印逻辑（直接调用自身 -h）
    $0 -h
    printf "${MAGENTA}========================================${NC}\n"
    printf "\n"
    printf "${MAGENTA}==== waveproxy (proxy decision engine) ====${NC}\n"
    waveproxy -h 2>/dev/null || echo "🌊 waveproxy command not found."
    printf "${MAGENTA}==========================================${NC}\n"
    printf "\n"
    printf "${MAGENTA}==== proxydeploy (configuration management) ====${NC}\n"
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
