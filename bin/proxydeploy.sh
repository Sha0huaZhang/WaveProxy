#!/bin/bash
# proxydeploy.sh - 配置管理工具
# 用于查看、编辑、切换 WaveProxy 配置文件

# 显示帮助（含示例）
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo -e "\033[35musage: \033[38;5;197mproxydeploy <subcommand> [@config_name] [flags]\033[0m"
    echo
    echo "proxydeploy 1.0.0 🌊"
    echo "Configuration management tool for WaveProxy."
    echo
    echo -e "\033[35mSubcommands:\033[0m"
    echo "  \033[32mproxydeploy\033[0m               Show current default config name"
    echo "  \033[32mlist\033[0m [@name]             View config content (default: default)"
    echo "  \033[32medit\033[0m [@name]             Edit config with nano (default: default)"
    echo "  \033[32mrun --change-to-default @new @old\033[0m  Switch default config"
    echo "  \033[32mrun --print-working-proxy\033[0m  Print the currently active proxy variable"
    echo "  \033[32mrun --print-default-proxy\033[0m   Print the default proxy variable from the config"
    echo
    echo "  \033[32mrun --print-detailed-working-proxy\033[0m  Print detailed content of the current config"
    echo "  \033[32mrun --print-detailed-default-proxy\033[0m  Print detailed content of the default config"
    echo "  \033[32mrun --print-detailed-all-proxy\033[0m      Print detailed content of ALL configs"
    echo "  \033[32mrun --print-all-proxy\033[0m               List all available config files"
    echo
    echo "  \033[32mrun --create-new-proxy @name\033[0m        Create and edit a new config file"
    echo "  \033[32mrun --enforce-proxy @name [--once]\033[0m  Enforce a config (session or once)"
    echo "  \033[32mrun --enforce-proxy \"url\" [--once]\033[0m  Enforce a proxy address (session or once)"
    echo "  \033[32mrun --ignore-proxy @name [--once]\033[0m   Ignore a config (session or once)"
    echo "  \033[32mrun --ignore-proxy \"url\" [--once]\033[0m   Ignore a proxy address (session or once)"
    echo "  \033[32mrun --provisional-start\033[0m             Start provisional mode"
    echo "  \033[32mrun --provisional-end\033[0m               End provisional mode"
    echo
    echo -e "\033[35mFlags:\033[0m"
    echo "  \033[32m-h, --help\033[0m          Show this help message and exit"
    echo
    echo -e "\033[35mExamples:\033[0m"
    echo "  # View current default config name"
    echo "  \033[32mproxydeploy\033[0m"
    echo ""
    echo "  # View default config content"
    echo "  \033[32mproxydeploy list\033[0m"
    echo ""
    echo "  # View a specific config"
    echo "  \033[32mproxydeploy list @work\033[0m"
    echo ""
    echo "  # Edit default config with nano"
    echo "  \033[32mproxydeploy edit\033[0m"
    echo ""
    echo "  # Edit a specific config"
    echo "  \033[32mproxydeploy edit @work\033[0m"
    echo ""
    echo "  # Switch default config to 'work'"
    echo "  \033[32mproxydeploy run --change-to-default @work @default\033[0m"
    echo ""
    echo "  # Print current working proxy"
    echo "  \033[32mproxydeploy run --print-working-proxy\033[0m"
    echo ""
    echo "  # Print default proxy from config"
    echo "  \033[32mproxydeploy run --print-default-proxy\033[0m"
    echo ""
    echo "  # Print detailed content of current config"
    echo "  \033[32mproxydeploy run --print-detailed-working-proxy\033[0m"
    echo ""
    echo "  # Print detailed content of default config"
    echo "  \033[32mproxydeploy run --print-detailed-default-proxy\033[0m"
    echo ""
    echo "  # Print detailed content of ALL configs"
    echo "  \033[32mproxydeploy run --print-detailed-all-proxy\033[0m"
    echo ""
    echo "  # List all available config files"
    echo "  \033[32mproxydeploy run --print-all-proxy\033[0m"
    echo ""
    echo "  # Create and edit a new config"
    echo "  \033[32mproxydeploy run --create-new-proxy @project\033[0m"
    echo ""
    echo "  # Enforce a config for current session"
    echo "  \033[32mproxydeploy run --enforce-proxy @work\033[0m"
    echo ""
    echo "  # Enforce a config for the next query only"
    echo "  \033[32mproxydeploy run --enforce-proxy @work --once\033[0m"
    echo ""
    echo "  # Ignore a config for current session"
    echo "  \033[32mproxydeploy run --ignore-proxy @home\033[0m"
    echo ""
    echo "  # Ignore a config for the next query only"
    echo "  \033[32mproxydeploy run --ignore-proxy @home --once\033[0m"
    echo ""
    echo "  # Start provisional mode"
    echo "  \033[32mproxydeploy run --provisional-start\033[0m"
    echo ""
    echo "  # End provisional mode"
    echo "  \033[32mproxydeploy run --provisional-end\033[0m"
    echo ""
    echo "For more details, visit: https://proxy.macwave.org"
    exit 0
fi

# --- 处理 --help-all ---
if [[ "$1" == "--help-all" ]]; then
    echo -e "\033[35m==== proxydeploy (configuration management) ====\033[0m"
    # 复用 -h 的打印逻辑（直接调用自身 -h）
    $0 -h
    echo -e "\033[35m================================================\033[0m"
    echo
    echo -e "\033[35m==== waveproxy (proxy decision engine) ====\033[0m"
    waveproxy -h 2>/dev/null || echo "🌊 waveproxy command not found."
    echo -e "\033[35m==========================================\033[0m"
    echo
    echo -e "\033[35m==== proxywrap (auto-inject wrapper) ====\033[0m"
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
            printf "\033[32m%${padding}s\033[0m\n" "$marker"
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

            NEW_FILE="$CONFIG_DIR/proxydeploy@${NEW_NAME}.txt"
            if [ ! -f "$NEW_FILE" ]; then
                echo "🌊 Error: Config not found: proxydeploy@${NEW_NAME}.txt"
                exit 1
            fi

            OLD_FILE="$CONFIG_DIR/proxydeploy@${OLD_NAME}.txt"
            if [ ! -f "$OLD_FILE" ]; then
                echo "🌊 Warning: Old config not found: proxydeploy@${OLD_NAME}.txt"
            fi

            echo "🌊 Switching default config from $OLD_NAME to $NEW_NAME"
            cp "$NEW_FILE" "$CONFIG_DIR/proxydeploy@default.txt"

            echo "🌊 export WAVEPROXY_CONFIG=$NEW_NAME" > "$CONFIG_DIR/.default_config"

            echo "🌊 Default config updated to: $NEW_NAME"
            echo "🌊 WaveProxy will use $NEW_NAME on next query."
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
                        printf "%s%${padding}s\033[32m%s\033[0m\n" "$name" "" "$marker"
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
                echo -e "\033[31m🌊 Error: Config '${NEW_NAME}' already exists. Use 'proxydeploy edit @${NEW_NAME}' to edit it.\033[0m"
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
                echo "🌊 Usage: proxydeploy run --enforce-proxy @config_name | \"proxy_url\" [--once]"
                exit 1
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
                echo "🌊 Usage: proxydeploy run --ignore-proxy @config_name | \"proxy_url\" [--once]"
                exit 1
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

        # --- 开启临时模式（带确认机制） ---
        if [ "$1" = "--provisional-start" ]; then
            # 检查是否存在正在进行的 provisional 环境变量
            if [ -n "$WAVEPROXY_ENFORCE_CONFIG" ] || \
               [ -n "$WAVEPROXY_ENFORCE_PROXY" ] || \
               [ -n "$WAVEPROXY_IGNORE_CONFIG" ] || \
               [ -n "$WAVEPROXY_IGNORE_PROXY" ] || \
               [ -n "$WAVEPROXY_ONCE_ENFORCE_CONFIG" ] || \
               [ -n "$WAVEPROXY_ONCE_ENFORCE_PROXY" ] || \
               [ -n "$WAVEPROXY_ONCE_IGNORE_CONFIG" ] || \
               [ -n "$WAVEPROXY_ONCE_IGNORE_PROXY" ]; then
                echo -e "\033[31m🌊 There is already an ongoing provisional session.\033[0m"
                echo -e "\033[31m🌊 Continuing will clear all current provisional settings.\033[0m"
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
            echo "🌊 Provisional mode started. All temporary settings will remain until --provisional-end or terminal close."
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

        echo "🌊 Usage: proxydeploy run --change-to-default @new @old | --print-working-proxy | --print-default-proxy | --print-detailed-working-proxy | --print-detailed-default-proxy | --print-detailed-all-proxy | --print-all-proxy | --create-new-proxy @name | --enforce-proxy @name/url [--once] | --ignore-proxy @name/url [--once] | --provisional-start | --provisional-end"
        exit 1
        ;;

    *)
        echo "🌊 Unknown command: $CMD"
        echo "🌊 Available commands: status, list, edit, run"
        exit 1
        ;;
esac
