#!/bin/bash
# WaveProxy v1.0 官方安装脚本
# 安装路径：~/.local/waveproxy/

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🌊 Installing WaveProxy v1.0..."

# 1. 创建目录
mkdir -p ~/.local/waveproxy/bin

# 2. 下载主程序
echo "🌊 Downloading waveproxy.py..."
curl -L https://waveproxy.org/v1.0/waveproxy.py -o ~/.local/waveproxy/bin/waveproxy.py
chmod +x ~/.local/waveproxy/bin/waveproxy.py
echo -e "${GREEN}🌊 waveproxy.py downloaded successfully${NC}"

# 3. 下载 proxywrap.sh
echo "🌊 Downloading proxywrap.sh..."
curl -L https://waveproxy.org/v1.0/proxywrap.sh -o ~/.local/waveproxy/bin/proxywrap.sh
chmod +x ~/.local/waveproxy/bin/proxywrap.sh
echo -e "${GREEN}🌊 proxywrap.sh downloaded successfully${NC}"

# 4. 创建 proxydeploy 快捷脚本
echo "🌊 Creating proxydeploy command..."
cat > ~/.local/waveproxy/bin/proxydeploy << 'EOF'
#!/bin/bash
# proxydeploy - 配置管理工具

CONFIG_DIR="$HOME/.local/waveproxy"
DEFAULT_NAME="main"

CURRENT_NAME="${WAVEPROXY_CONFIG:-$DEFAULT_NAME}"

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
EOF
chmod +x ~/.local/waveproxy/bin/proxydeploy
echo -e "${GREEN}🌊 proxydeploy command created successfully${NC}"

# 5. 创建默认配置文件
if [ ! -f ~/.local/waveproxy/proxydeploy@main.txt ]; then
    echo "🌊 Generating default config file..."
    curl -L https://waveproxy.org/v1.0/proxydeploy@main.txt -o ~/.local/waveproxy/proxydeploy@main.txt
    echo -e "${GREEN}🌊 Default config file generated successfully${NC}"
fi

# 6. 下载 README
echo "🌊 Downloading README.md..."
curl -L https://waveproxy.org/v1.0/README.md -o ~/.local/waveproxy/README.md
echo -e "${GREEN}🌊 README.md downloaded successfully${NC}"

# 7. 将 bin 加入 PATH
if ! echo "$PATH" | grep -q "$HOME/.local/waveproxy/bin"; then
    echo 'export PATH="$HOME/.local/waveproxy/bin:$PATH"' >> ~/.bashrc
    echo 'export PATH="$HOME/.local/waveproxy/bin:$PATH"' >> ~/.zshrc
    echo -e "${GREEN}🌊 PATH updated. Please restart your shell or run: exec \$SHELL${NC}"
fi

echo ""
echo -e "${GREEN}🌊 WaveProxy v1.0 installation complete!${NC}"
echo ""
echo -e "${GREEN}🌊 Quick start:${NC}"
echo "  waveproxy query github.com          # Query proxy for a URL"
echo "  proxywrap curl -LO <url>            # Auto-proxy download"
echo "  proxydeploy                         # Show current default config name"
echo "  proxydeploy edit                    # Edit default config"
echo "  proxydeploy list @work              # View work config"
echo ""
echo -e "${GREEN}🌊 Config file: ~/.local/waveproxy/proxydeploy@main.txt${NC}"
echo -e "${GREEN}🌊 Uninstall: rm -rf ~/.local/waveproxy${NC}"
