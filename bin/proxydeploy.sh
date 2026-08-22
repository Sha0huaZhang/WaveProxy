#!/bin/bash
# proxydeploy.sh - 配置管理工具
# 用于查看、编辑、切换 WaveProxy 配置文件

# ================== 颜色变量定义 ==================
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
LIGHTBLUE='\033[94m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'
NC='\033[0m'  # No Color
# =================================================

# 显示帮助（含示例，使用 printf 确保颜色渲染）
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    printf "${BLUE}usage: ${LIGHTBLUE}proxydeploy <subcommand> [@config_name] [flags]${NC}\n"
    printf "\n"
    printf "proxydeploy 1.0.0 🌊\n"
    printf "Configuration management tool for WaveProxy.\n"
    printf "\n"
    printf "${LIGHTBLUE}Subcommands:${NC}\n"
    printf "  ${GREEN}proxydeploy${NC}                                 Show current default config name\n"
    printf "  ${GREEN}list${NC} ${BOLD}${YELLOW}[@name]${NC}                          View config content (default: default)\n"
    printf "  ${GREEN}edit${NC} ${BOLD}${YELLOW}[@name]${NC}                        Edit config with nano (default: default)\n"
    printf "  ${GREEN}run --change-to-default ${BOLD}${YELLOW}@new${NC} ${YELLOW}@old${NC}                      Switch default config\n"
    printf "  ${GREEN}run --change-to-default ${BOLD}${YELLOW}None${NC}                             Restore default config\n"
    printf "  ${GREEN}run --print-working-proxy${NC}          Print the currently active proxy variable\n"
    printf "  ${GREEN}run --print-default-proxy${NC}   Print the default proxy variable from the config\n"
    printf "\n"
    printf "  ${GREEN}run --print-detailed-working-proxy${NC}Print detailed content of the current config\n"
    printf "  ${GREEN}run --print-detailed-default-proxy${NC}Print detailed content of the default config\n"
    printf "  ${GREEN}run --print-detailed-all-proxy${NC}           Print detailed content of ALL configs\n"
    printf "  ${GREEN}run --print-all-proxy${NC}                          List all available config files\n"
    printf "\n"
    printf "  ${GREEN}run --create-new-proxy ${BOLD}${YELLOW}@name${NC}                Create and edit a new config file\n"
    printf "  ${GREEN}run --enforce-proxy ${BOLD}${YELLOW}@name${NC} ${YELLOW}[--once]${NC}         Enforce a config (session or once)\n"
    printf "  ${GREEN}run --enforce-proxy ${BOLD}${YELLOW}\"url\"${NC} ${YELLOW}[--once]${NC}  Enforce a proxy address (session or once)\n"
    printf "  ${GREEN}run --enforce-proxy ${BOLD}${YELLOW}None${NC} ${YELLOW}[--once]${NC}                     Force direct connection\n"
    printf "  ${GREEN}run --ignore-proxy ${BOLD}${YELLOW}@name${NC} ${YELLOW}[--once]${NC}           Ignore a config (session or once)\n"
    printf "  ${GREEN}run --ignore-proxy ${BOLD}${YELLOW}\"url\"${NC} ${YELLOW}[--once]${NC}    Ignore a proxy address (session or once)\n"
    printf "  ${GREEN}run --ignore-proxy ${BOLD}${YELLOW}None${NC} ${YELLOW}[--once]${NC}                     Ignore direct connection\n"
    printf "  ${GREEN}run --provisional-start ${BOLD}${YELLOW}@name${NC}                          Start provisional mode\n"
    printf "  ${GREEN}run --provisional-start ${BOLD}${YELLOW}\"url\"${NC}                          Start provisional mode\n"
    printf "  ${GREEN}run --provisional-start ${BOLD}${YELLOW}None${NC}    Start provisional mode with direct connection\n"
    printf "  ${GREEN}run --provisional-end${NC}                                    End provisional mode\n"
    printf "\n"
    printf "${LIGHTBLUE}Flags:${NC}\n"
    printf "  ${GREEN}-h, --help${NC}                                    Show this help message and exit\n"
    printf "\n"
    printf "${LIGHTBLUE}Examples:${NC}\n"
    printf "  # View current default config name\n"
    printf "  ${GREEN}proxydeploy${NC}\n"
    printf "\n"
    printf "  # View default config content\n"
    printf "  ${GREEN}proxydeploy list${NC}\n"
    printf "\n"
    printf "  # View a specific config\n"
    printf "  ${GREEN}proxydeploy list ${BOLD}${YELLOW}@work${NC}\n"
    printf "\n"
    printf "  # Edit default config with nano\n"
    printf "  ${GREEN}proxydeploy edit${NC}\n"
    printf "\n"
    printf "  # Edit a specific config\n"
    printf "  ${GREEN}proxydeploy edit ${BOLD}${YELLOW}@work${NC}\n"
    printf "\n"
    printf "  # Switch default config to 'work'\n"
    printf "  ${GREEN}proxydeploy run --change-to-default ${BOLD}${YELLOW}@work${NC} ${YELLOW}@default${NC}\n"
    printf "\n"
    printf "  # Restore default config to 'default'\n"
    printf "  ${GREEN}proxydeploy run --change-to-default None${NC}\n"
    printf "\n"
    printf "  # Print current working proxy\n"
    printf "  ${GREEN}proxydeploy run --print-working-proxy${NC}\n"
    printf "\n"
    printf "  # Print default proxy from config\n"
    printf "  ${GREEN}proxydeploy run --print-default-proxy${NC}\n"
    printf "\n"
    printf "  # Print detailed content of current config\n"
    printf "  ${GREEN}proxydeploy run --print-detailed-working-proxy${NC}\n"
    printf "\n"
    printf "  # Print detailed content of default config\n"
    printf "  ${GREEN}proxydeploy run --print-detailed-default-proxy${NC}\n"
    printf "\n"
    printf "  # Print detailed content of ALL configs\n"
    printf "  ${GREEN}proxydeploy run --print-detailed-all-proxy${NC}\n"
    printf "\n"
    printf "  # List all available config files\n"
    printf "  ${GREEN}proxydeploy run --print-all-proxy${NC}\n"
    printf "\n"
    printf "  # Create and edit a new config\n"
    printf "  ${GREEN}proxydeploy run --create-new-proxy ${BOLD}${YELLOW}@project${NC}\n"
    printf "\n"
    printf "  # Enforce a config for current session\n"
    printf "  ${GREEN}proxydeploy run --enforce-proxy ${BOLD}${YELLOW}@work${NC}\n"
    printf "\n"
    printf "  # Enforce a config for the next query only\n"
    printf "  ${GREEN}proxydeploy run --enforce-proxy ${BOLD}${YELLOW}@work${NC} ${YELLOW}--once${NC}\n"
    printf "\n"
    printf "  # Ignore a config for current session\n"
    printf "  ${GREEN}proxydeploy run --ignore-proxy ${BOLD}${YELLOW}@home${NC}\n"
    printf "\n"
    printf "  # Ignore a config for the next query only\n"
    printf "  ${GREEN}proxydeploy run --ignore-proxy ${BOLD}${YELLOW}@home${NC} ${YELLOW}--once${NC}\n"
    printf "\n"
    printf "  # Start provisional mode\n"
    printf "  ${GREEN}proxydeploy run --provisional-start ${BOLD}${YELLOW}@name${NC}\n"
    printf "\n"
    printf "  # Start provisional mode\n"
    printf "  ${GREEN}proxydeploy run --provisional-start ${BOLD}${YELLOW}\"url\"${NC}\n"
    printf "\n"
    printf "  # End provisional mode\n"
    printf "  ${GREEN}proxydeploy run --provisional-end${NC}\n"
    printf "\n"
    printf "For more details, visit: ${BOLD}${BLUE}https://proxy.macwave.org${NC}"
    exit 0
fi

# --- 处理 --help-all ---
if [[ "$1" == "--help-all" ]]; then
    printf "\n"
    printf "\033[34m============proxydeploy (configuration management)============\033[0m\n"
    printf "\n"
    # 复用 -h 的打印逻辑（直接调用自身 -h）
    $0 -h
    printf "\n"
    printf "\n"
    printf "\033[34m============waveproxy (proxy decision engine)============\033[0m\n"
    printf "\n"
    waveproxy -h 2>/dev/null || echo "🌊 waveproxy command not found."
    printf "\n"
    printf "\033[34m============proxywrap (auto-inject wrapper)============\033[0m\n"
    printf "\n"
    proxywrap -h 2>/dev/null || echo "🌊 proxywrap command not found."
    exit 0
fi

CONFIG_DIR="$HOME/.local/waveproxy"
DEFAULT_NAME="default"

# 获取当前默认配置名（从环境变量或默认）
CURRENT_NAME="${WAVEPROXY_CONFIG:-$DEFAULT_NAME}"

# ========================================
# 辅助函数
# ========================================

# 获取所有配置文件名列表（不带 @ 后缀）
get_all_configs() {
    find "$CONFIG_DIR" -maxdepth 1 -name "proxydeploy@*.txt" | \
        sed -n 's/.*proxydeploy@\(.*\)\.txt/\1/p' | sort
}

# 获取当前正在工作的配置名（通过环境变量或 .default_config）
get_working_config_name() {
    if [ -n "$WAVEPROXY_CONFIG" ]; then
        echo "$WAVEPROXY_CONFIG"
    elif [ -f "$CONFIG_DIR/.default_config" ]; then
        sed -n 's/export WAVEPROXY_CONFIG=\(.*\)/\1/p' "$CONFIG_DIR/.default_config" | head -n1
    else
        echo "$DEFAULT_NAME"
    fi
}

# 打印详细配置内容，并在末尾右对齐加上标记（仅当前配置为绿色）
print_detailed_config() {
    local config_name="$1"
    local config_file="$CONFIG_DIR/proxydeploy@${config_name}.txt"

    if [ ! -f "$config_file" ]; then
        echo "🌊 Config '${config_name}' not found."
        return 1
    fi

    echo "==== $config_name ===="
    cat "$config_file"

    local working_name
    working_name=$(get_working_config_name)

    local marker=""
    if [ "$config_name" = "$DEFAULT_NAME" ]; then
        marker="----default"
    elif [ "$config_name" = "$working_name" ]; then
        marker="----working"
    fi

    if [ -n "$marker" ]; then
        # 获取终端宽度
        local term_width
        term_width=$(tput cols 2>/dev/null || echo 80)
        local marker_len=${#marker}
        local padding=$((term_width - marker_len))
        if [ $padding -lt 1 ]; then
            padding=1
        fi

        # 如果当前配置就是 working，用绿色；否则用黑色（无颜色）
        if [ "$config_name" = "$working_name" ]; then
            printf "${GREEN}%${padding}s${NC}\n" "$marker"
        else
            printf "%${padding}s\n" "$marker"
        fi
    fi
}

# ========================================
# 命令解析
# ========================================

CMD="${1:-status}"
shift 2>/dev/null || true

case "$CMD" in
    status|"")
        echo "$CURRENT_NAME"
        ;;

    list)
        TARGET="${1:-@$CURRENT_NAME}"
        TARGET="${TARGET#@}"
        CONFIG_FILE="$CONFIG_DIR/proxydeploy@${TARGET}.txt"
        if [ -f "$CONFIG_FILE" ]; then
            cat "$CONFIG_FILE"
        else
            echo "🌊 None"
            exit 1
        fi
        ;;

    edit)
        TARGET="${1:-@$CURRENT_NAME}"
        TARGET="${TARGET#@}"
        CONFIG_FILE="$CONFIG_DIR/proxydeploy@${TARGET}.txt"
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "🌊 Creating new config: proxydeploy@${TARGET}.txt"
            touch "$CONFIG_FILE"
        fi
        nano "$CONFIG_FILE"
        ;;

    run)
        # --- 切换默认配置 ---
        if [ "$1" = "--change-to-default" ]; then
            NEW_NAME="${2#@}"
            OLD_NAME="${3#@}"

            # 大小写不敏感判断 None（恢复默认配置）
            TARGET_LOWER=$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')
            if [[ "$TARGET_LOWER" == "none" ]]; then
                echo "🌊 Restoring default config to default."
                cp "$CONFIG_DIR/proxydeploy@default.txt" "$CONFIG_DIR/proxydeploy@default.txt.tmp"
                mv "$CONFIG_DIR/proxydeploy@default.txt.tmp" "$CONFIG_DIR/proxydeploy@default.txt"
                echo "🌊 Default config restored to default."
                exit 0
            fi

            NEW_FILE="$CONFIG_DIR/proxydeploy@${NEW_NAME}.txt"
            if [ ! -f "$NEW_FILE" ]; then
                echo -e "\033[31mError: Config not found: proxydeploy@${NEW_NAME}.txt\033[0m"
                exit 1
            fi

            OLD_FILE="$CONFIG_DIR/proxydeploy@${OLD_NAME}.txt"
            if [ ! -f "$OLD_FILE" ]; then
                echo -e "\033[33mWarning: Old config not found: proxydeploy@${OLD_NAME}.txt\033[0m"
            fi

            echo -e "\033[33mDefault config will be changed:\033[0m"
            echo -e "  \033[31mOld: $OLD_NAME\033[0m"
            echo -e "  \033[32mNew: $NEW_NAME\033[0m"
            echo -n "Are you sure? [Y/n] "
            read -n 1 -r REPLY
            echo
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                echo -e "\033[31mOperation cancelled.\033[0m"
                exit 0
            fi

            echo -e "\033[32mSwitching default config from $OLD_NAME to $NEW_NAME\033[0m"
            cp "$NEW_FILE" "$CONFIG_DIR/proxydeploy@default.txt"

            echo "🌊 export WAVEPROXY_CONFIG=$NEW_NAME" > "$CONFIG_DIR/.default_config"

            echo -e "\033[32mDefault config updated to: $NEW_NAME\033[0m"
            echo -e "\033[32mWaveProxy will use $NEW_NAME on next query.\033[0m"
            exit 0
        fi

        # --- 打印当前工作代理变量 ---
        if [ "$1" = "--print-working-proxy" ]; then
            CONFIG_FILE="$CONFIG_DIR/proxydeploy@${CURRENT_NAME}.txt"
            if [ ! -f "$CONFIG_FILE" ]; then
                echo "🌊 None"
                exit 1
            fi
            WORKING_PROXY=$(grep -v '^[[:space:]]*<!--' "$CONFIG_FILE" | grep -m 1 '^[[:space:]]*let "' | sed -n 's/.*let "\([^"]*\)".*/\1/p')
            if [ -z "$WORKING_PROXY" ]; then
                echo "🌊 None"
            else
                echo "🌊 $WORKING_PROXY"
            fi
            exit 0
        fi

        # --- 打印默认代理变量 ---
        if [ "$1" = "--print-default-proxy" ]; then
            DEFAULT_CONFIG="$CONFIG_DIR/proxydeploy@default.txt"
            if [ ! -f "$DEFAULT_CONFIG" ]; then
                echo "🌊 None"
                exit 1
            fi
            DEFAULT_PROXY=$(grep -v '^[[:space:]]*<!--' "$DEFAULT_CONFIG" | grep -m 1 '^[[:space:]]*let "' | sed -n 's/.*let "\([^"]*\)".*/\1/p')
            if [ -z "$DEFAULT_PROXY" ]; then
                echo "🌊 None"
            else
                echo "🌊 $DEFAULT_PROXY"
            fi
            exit 0
        fi

        # --- 打印详细当前工作配置 ---
        if [ "$1" = "--print-detailed-working-proxy" ]; then
            print_detailed_config "$(get_working_config_name)"
            exit 0
        fi

        # --- 打印详细默认配置 ---
        if [ "$1" = "--print-detailed-default-proxy" ]; then
            print_detailed_config "$DEFAULT_NAME"
            exit 0
        fi

        # --- 打印详细所有配置 ---
        if [ "$1" = "--print-detailed-all-proxy" ]; then
            all_configs=$(get_all_configs)
            if [ -z "$all_configs" ]; then
                echo "🌊 No config files found."
                exit 0
            fi
            for name in $all_configs; do
                echo ""
                print_detailed_config "$name"
                echo ""
            done
            exit 0
        fi

        # --- 列出所有配置名（左右对齐 + 右对齐标记） ---
        if [ "$1" = "--print-all-proxy" ]; then
            all_configs=$(get_all_configs)
            if [ -z "$all_configs" ]; then
                echo "🌊 No config files found."
                exit 0
            fi

            working_name=$(get_working_config_name)
            term_width=$(tput cols 2>/dev/null || echo 80)

            for name in $all_configs; do
                # 构建右侧标记
                marker=""
                if [ "$name" = "$DEFAULT_NAME" ]; then
                    marker="----default"
                elif [ "$name" = "$working_name" ]; then
                    marker="----working"
                fi

                # 计算填充长度，减去右侧标记长度再留 2 个空格缓冲
                if [ -n "$marker" ]; then
                    marker_len=${#marker}
                    padding=$((term_width - marker_len - 2))
                    if [ $padding -lt 1 ]; then
                        padding=1
                    fi
                    # 配置名 + 填充 + 标记（带颜色）
                    if [ "$name" = "$working_name" ]; then
                        printf "%s%${padding}s${GREEN}%s${NC}\n" "$name" "" "$marker"
                    else
                        printf "%s%${padding}s%s\n" "$name" "" "$marker"
                    fi
                else
                    # 无标记直接输出配置名
                    echo "$name"
                fi
            done
            exit 0
        fi

        # --- 创建并编辑新配置（若已存在则报错） ---
        if [ "$1" = "--create-new-proxy" ]; then
            NEW_NAME="${2#@}"
            if [ -z "$NEW_NAME" ]; then
                echo "🌊 Usage: proxydeploy run --create-new-proxy @name"
                exit 1
            fi

            NEW_FILE="$CONFIG_DIR/proxydeploy@${NEW_NAME}.txt"
            if [ -f "$NEW_FILE" ]; then
                printf "${RED}🌊 Error: Config '${NEW_NAME}' already exists. Use 'proxydeploy edit @${NEW_NAME}' to edit it.${NC}\n"
                exit 1
            else
                echo "🌊 Creating new config: proxydeploy@${NEW_NAME}.txt"
                touch "$NEW_FILE"
                nano "$NEW_FILE"
            fi
            exit 0
        fi

        # --- 强制配置（环境变量版） ---
        if [ "$1" = "--enforce-proxy" ]; then
            TARGET="$2"
            if [ -z "$TARGET" ]; then
                echo "🌊 Usage: proxydeploy run --enforce-proxy @config_name | \"proxy_url\" | None"
                exit 1
            fi

            # 大小写不敏感判断 None
            TARGET_LOWER=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')
            if [[ "$TARGET_LOWER" == "none" ]]; then
                export WAVEPROXY_ENFORCE_PROXY="None"
                echo "🌊 Enforced direct connection (None)."
                exit 0
            fi

            # 检查是否带了 --once
            ONCE_FLAG=""
            if [[ "$3" == "--once" ]]; then
                ONCE_FLAG="ONCE"
            fi

            if [[ "$TARGET" == @* ]]; then
                CONFIG_NAME="${TARGET#@}"
                if [ "$ONCE_FLAG" = "ONCE" ]; then
                    export WAVEPROXY_ONCE_ENFORCE_CONFIG="$CONFIG_NAME"
                    echo "🌊 Config '${CONFIG_NAME}' enforced for the next query only (--once)."
                else
                    export WAVEPROXY_ENFORCE_CONFIG="$CONFIG_NAME"
                    echo "🌊 Config '${CONFIG_NAME}' enforced for current session."
                fi
            else
                if [ "$ONCE_FLAG" = "ONCE" ]; then
                    export WAVEPROXY_ONCE_ENFORCE_PROXY="$TARGET"
                    echo "🌊 Proxy '$TARGET' enforced for the next query only (--once)."
                else
                    export WAVEPROXY_ENFORCE_PROXY="$TARGET"
                    echo "🌊 Proxy '$TARGET' enforced for current session."
                fi
            fi
            exit 0
        fi

        # --- 忽略配置（环境变量版） ---
        if [ "$1" = "--ignore-proxy" ]; then
            TARGET="$2"
            if [ -z "$TARGET" ]; then
                echo "🌊 Usage: proxydeploy run --ignore-proxy @config_name | \"proxy_url\" | None"
                exit 1
            fi

            # 大小写不敏感判断 None
            TARGET_LOWER=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')
            if [[ "$TARGET_LOWER" == "none" ]]; then
                export WAVEPROXY_IGNORE_PROXY="None"
                echo "🌊 Ignored direct connection (None)."
                exit 0
            fi

            # 检查是否带了 --once
            ONCE_FLAG=""
            if [[ "$3" == "--once" ]]; then
                ONCE_FLAG="ONCE"
            fi

            if [[ "$TARGET" == @* ]]; then
                CONFIG_NAME="${TARGET#@}"
                if [ "$ONCE_FLAG" = "ONCE" ]; then
                    export WAVEPROXY_ONCE_IGNORE_CONFIG="$CONFIG_NAME"
                    echo "🌊 Config '${CONFIG_NAME}' ignored for the next query only (--once)."
                else
                    export WAVEPROXY_IGNORE_CONFIG="$CONFIG_NAME"
                    echo "🌊 Config '${CONFIG_NAME}' ignored for current session."
                fi
            else
                if [ "$ONCE_FLAG" = "ONCE" ]; then
                    export WAVEPROXY_ONCE_IGNORE_PROXY="$TARGET"
                    echo "🌊 Proxy '$TARGET' ignored for the next query only (--once)."
                else
                    export WAVEPROXY_IGNORE_PROXY="$TARGET"
                    echo "🌊 Proxy '$TARGET' ignored for current session."
                fi
            fi
            exit 0
        fi

        # --- 开启临时模式（带参数，立即生效） ---
        if [ "$1" = "--provisional-start" ]; then
            TARGET="$2"
            if [ -z "$TARGET" ]; then
                echo "🌊 Usage: proxydeploy run --provisional-start @config_name | \"proxy_url\" | None"
                exit 1
            fi

            # 大小写不敏感判断 None
            TARGET_LOWER=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')
            if [[ "$TARGET_LOWER" == "none" ]]; then
                export WAVEPROXY_ENFORCE_PROXY="None"
                echo "🌊 Provisional mode started with direct connection (None)."
                exit 0
            fi

            # 检查是否存在正在进行的 provisional 环境变量
            if [ -n "$WAVEPROXY_ENFORCE_CONFIG" ] || \
               [ -n "$WAVEPROXY_ENFORCE_PROXY" ] || \
               [ -n "$WAVEPROXY_IGNORE_CONFIG" ] || \
               [ -n "$WAVEPROXY_IGNORE_PROXY" ] || \
               [ -n "$WAVEPROXY_ONCE_ENFORCE_CONFIG" ] || \
               [ -n "$WAVEPROXY_ONCE_ENFORCE_PROXY" ] || \
               [ -n "$WAVEPROXY_ONCE_IGNORE_CONFIG" ] || \
               [ -n "$WAVEPROXY_ONCE_IGNORE_PROXY" ]; then
                printf "${RED}🌊 There is already an ongoing provisional session.${NC}\n"
                printf "${RED}🌊 Continuing will clear all current provisional settings.${NC}\n"
                echo -n "🌊 Are you sure you want to continue? [Y/n] "
                read -n 1 -r REPLY
                echo
                if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                    echo "🌊 Provisional start cancelled."
                    exit 0
                fi
                # 用户确认，清空所有现有的 provisional 环境变量
                unset WAVEPROXY_ENFORCE_CONFIG
                unset WAVEPROXY_ENFORCE_PROXY
                unset WAVEPROXY_IGNORE_CONFIG
                unset WAVEPROXY_IGNORE_PROXY
                unset WAVEPROXY_ONCE_ENFORCE_CONFIG
                unset WAVEPROXY_ONCE_ENFORCE_PROXY
                unset WAVEPROXY_ONCE_IGNORE_CONFIG
                unset WAVEPROXY_ONCE_IGNORE_PROXY
                echo "🌊 Existing provisional settings cleared."
            fi

            # 根据参数类型设置强制/忽略
            if [[ "$TARGET" == @* ]]; then
                CONFIG_NAME="${TARGET#@}"
                export WAVEPROXY_ENFORCE_CONFIG="$CONFIG_NAME"
                echo "🌊 Provisional mode started with enforced config: $CONFIG_NAME"
            else
                export WAVEPROXY_ENFORCE_PROXY="$TARGET"
                echo "🌊 Provisional mode started with enforced proxy: $TARGET"
            fi

            echo "🌊 Settings will remain until --provisional-end or terminal close."
            exit 0
        fi

        # --- 结束临时模式 ---
        if [ "$1" = "--provisional-end" ]; then
            unset WAVEPROXY_ENFORCE_CONFIG
            unset WAVEPROXY_ENFORCE_PROXY
            unset WAVEPROXY_IGNORE_CONFIG
            unset WAVEPROXY_IGNORE_PROXY
            unset WAVEPROXY_ONCE_ENFORCE_CONFIG
            unset WAVEPROXY_ONCE_ENFORCE_PROXY
            unset WAVEPROXY_ONCE_IGNORE_CONFIG
            unset WAVEPROXY_ONCE_IGNORE_PROXY
            echo "🌊 Provisional mode ended. All temporary settings cleared."
            exit 0
        fi

        echo -e "${BLUE}🌊 Usage: proxydeploy run${NC}"
        echo -e "${GREEN}  --change-to-default ${BOLD}${YELLOW}@new @old${NC}"
        echo -e "${GREEN}  --change-to-default ${BOLD}${YELLOW}None${NC}"
        echo -e "${GREEN}  --print-working-proxy${NC}"
        echo -e "${GREEN}  --print-default-proxy${NC}"
        echo -e "${GREEN}  --print-detailed-working-proxy${NC}"
        echo -e "${GREEN}  --print-detailed-default-proxy${NC}"
        echo -e "${GREEN}  --print-detailed-all-proxy${NC}"
        echo -e "${GREEN}  --print-all-proxy${NC}"
        echo -e "${GREEN}  --create-new-proxy ${BOLD}${YELLOW}@name${NC}"
        echo -e "${GREEN}  --enforce-proxy ${BOLD}${YELLOW}@name/"url"${NC} ${YELLOW}[--once]${NC}"
        echo -e "${GREEN}  --enforce-proxy ${BOLD}${YELLOW}None${NC} ${YELLOW}[--once]${NC}"
        echo -e "${GREEN}  --ignore-proxy ${BOLD}${YELLOW}@name/"url"${NC} ${YELLOW}[--once]${NC}"
        echo -e "${GREEN}  --ignore-proxy ${BOLD}${YELLOW}None${NC} ${YELLOW}[--once]${NC}"
        echo -e "${GREEN}  --provisional-start ${BOLD}${YELLOW}@name/"url"${NC}"
        echo -e "${GREEN}  --provisional-start ${BOLD}${YELLOW}None${NC}"
        echo -e "${GREEN}  --provisional-end${NC}"
        exit 1
        ;;

    *)
        echo "🌊 Unknown command: $CMD"
        echo "🌊 Available commands: status, list, edit, run"
        exit 1
        ;;
esac
