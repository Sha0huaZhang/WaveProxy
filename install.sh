#!/bin/bash
# WaveProxy v1.0 官方安装脚本
# 安装路径：~/.local/waveproxy/

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🌊 Installing WaveProxy v1.0..."

# 1. 创建目录
mkdir -p ~/.local/waveproxy/bin

# 2. 下载主程序
echo "🌊 Downloading waveproxy.py..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/waveproxy/main/bin/waveproxy.py -o ~/.local/waveproxy/bin/waveproxy.py
chmod +x ~/.local/waveproxy/bin/waveproxy.py
echo -e "${GREEN}🌊 waveproxy.py downloaded successfully${NC}"

# 3. 下载 proxywrap.sh
echo "🌊 Downloading proxywrap.sh..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/waveproxy/main/bin/proxywrap.sh -o ~/.local/waveproxy/bin/proxywrap.sh
chmod +x ~/.local/waveproxy/bin/proxywrap.sh
echo -e "${GREEN}🌊 proxywrap.sh downloaded successfully${NC}"

# 4. 下载 proxydeploy.sh
echo "🌊 Downloading proxydeploy.sh..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/waveproxy/main/bin/proxydeploy.sh -o ~/.local/waveproxy/bin/proxydeploy.sh
chmod +x ~/.local/waveproxy/bin/proxydeploy.sh
echo -e "${GREEN}🌊 proxydeploy.sh downloaded successfully${NC}"

# 创建不带 .sh 的软链接
ln -sf ~/.local/waveproxy/bin/proxydeploy.sh ~/.local/waveproxy/bin/proxydeploy
echo -e "${GREEN}🌊 Created symlink: proxydeploy -> proxydeploy.sh${NC}"

# 为 waveproxy.py 创建软链接
ln -sf ~/.local/waveproxy/bin/waveproxy.py ~/.local/waveproxy/bin/waveproxy
echo -e "${GREEN}🌊 Created symlink: waveproxy -> waveproxy.py${NC}"

# 5. 创建默认配置文件（改为 default）
if [ ! -f ~/.local/waveproxy/proxydeploy@default.txt ]; then
    echo "🌊 Generating default config file..."
    curl -L https://raw.githubusercontent.com/Sha0huaZhang/waveproxy/main/config/proxydeploy@default.txt -o ~/.local/waveproxy/proxydeploy@default.txt
    echo -e "${GREEN}🌊 Default config file generated successfully${NC}"
fi

# 6. 下载 README
echo "🌊 Downloading README.md..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/waveproxy/main/docs/README.md -o ~/.local/waveproxy/README.md
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
echo -e "${GREEN}🌊 Config file: ~/.local/waveproxy/proxydeploy@default.txt${NC}"
echo -e "${RED}🌊 Uninstall: rm -rf ~/.local/waveproxy${NC}"
