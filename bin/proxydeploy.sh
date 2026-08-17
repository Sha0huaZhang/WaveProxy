#!/bin/bash
# proxydeploy.sh - 配置管理工具
# 用于查看、编辑、切换 WaveProxy 配置文件

CONFIG_DIR="$HOME/.local/waveproxy"
DEFAULT_NAME="main"

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
            cp "$NEW_FILE" "$CONFIG_DIR/proxydeploy@main.txt"
            
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
