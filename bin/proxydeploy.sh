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
    echo "For more details, visit: https://waveproxy.org"
    exit 0
fi

CONFIG_DIR="$HOME/.local/waveproxy"
# 默认配置名改为 default
DEFAULT_NAME="default"

# 获取当前默认配置名（从环境变量或默认）
CURRENT_NAME="${WAVEPROXY_CONFIG:-$DEFAULT_NAME}"

# 解析命令
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
            echo "None"
            exit 1
        fi
        ;;
    
    edit)
        TARGET="${1:-@$CURRENT_NAME}"
        TARGET="${TARGET#@}"
        CONFIG_FILE="$CONFIG_DIR/proxydeploy@${TARGET}.txt"
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "📄 Creating new config: proxydeploy@${TARGET}.txt"
            touch "$CONFIG_FILE"
        fi
        nano "$CONFIG_FILE"
        ;;
    
    run)
        if [ "$1" = "--change-to-default" ]; then
            NEW_NAME="${2#@}"
            OLD_NAME="${3#@}"
            
            NEW_FILE="$CONFIG_DIR/proxydeploy@${NEW_NAME}.txt"
            if [ ! -f "$NEW_FILE" ]; then
                echo "Error: Config not found: proxydeploy@${NEW_NAME}.txt"
                exit 1
            fi
            
            OLD_FILE="$CONFIG_DIR/proxydeploy@${OLD_NAME}.txt"
            if [ ! -f "$OLD_FILE" ]; then
                echo "Warning: Old config not found: proxydeploy@${OLD_NAME}.txt"
            fi
            
            echo "Switching default config from $OLD_NAME to $NEW_NAME"
            cp "$NEW_FILE" "$CONFIG_DIR/proxydeploy@default.txt"
            
            echo "export WAVEPROXY_CONFIG=$NEW_NAME" > "$CONFIG_DIR/.default_config"
            
            echo "🌊 Default config updated to: $NEW_NAME"
            echo "WaveProxy will use $NEW_NAME on next query."
        else
            echo "Usage: proxydeploy run --change-to-default @new @old"
            exit 1
        fi
        ;;
    
    *)
        echo "Unknown command: $CMD"
        echo "Available commands: status, list, edit, run"
        exit 1
        ;;
esac
