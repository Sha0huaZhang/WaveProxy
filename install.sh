#!/bin/bash
# WaveProxy v1.0.0-beta.1 官方安装脚本
# 安装路径：~/.local/waveproxy/

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "🌊 Welcome to WaveProxy!"
echo "🌊 Installing to ~/.local/waveproxy..."

# 1. 创建目录
mkdir -p ~/.local/waveproxy/bin
mkdir -p ~/.local/waveproxy/lib

# 2. 下载主程序
echo "🌊 Downloading waveproxy.rb..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/bin/waveproxy.rb -o ~/.local/waveproxy/bin/waveproxy.rb
chmod +x ~/.local/waveproxy/bin/waveproxy.rb
echo -e "${GREEN}🌊 waveproxy.rb downloaded successfully${NC}"

# 3. 下载包装器
echo "🌊 Downloading proxywrap.sh..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/bin/proxywrap.sh -o ~/.local/waveproxy/bin/proxywrap.sh
chmod +x ~/.local/waveproxy/bin/proxywrap.sh
echo -e "${GREEN}🌊 proxywrap.sh downloaded successfully${NC}"

# 4. 下载配置管理工具
echo "🌊 Downloading proxydeploy.sh..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/bin/proxydeploy.sh -o ~/.local/waveproxy/bin/proxydeploy.sh
chmod +x ~/.local/waveproxy/bin/proxydeploy.sh
echo -e "${GREEN}🌊 proxydeploy.sh downloaded successfully${NC}"

# 5. 创建软链接
ln -sf ~/.local/waveproxy/bin/proxydeploy.sh ~/.local/waveproxy/bin/proxydeploy
ln -sf ~/.local/waveproxy/bin/waveproxy.rb ~/.local/waveproxy/bin/waveproxy
ln -sf ~/.local/waveproxy/bin/proxywrap.sh ~/.local/waveproxy/bin/proxywrap

echo -e "${GREEN}🌊 Symlinks created${NC}"

# 6. 下载核心库
echo "🌊 Downloading parser.rb..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/lib/parser.rb -o ~/.local/waveproxy/lib/parser.rb
echo -e "${GREEN}🌊 parser.rb downloaded successfully${NC}"

echo "🌊 Downloading matcher.rb..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/lib/matcher.rb -o ~/.local/waveproxy/lib/matcher.rb
echo -e "${GREEN}🌊 matcher.rb downloaded successfully${NC}"

# 7. 创建默认配置文件
if [ ! -f ~/.local/waveproxy/proxydeploy@default.txt ]; then
    echo "🌊 Generating default config file..."
    curl -L https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/config/proxydeploy@default.txt -o ~/.local/waveproxy/proxydeploy@default.txt
    echo -e "${GREEN}🌊 Default config file generated successfully${NC}"
fi

# 8. 下载命令参考
echo "🌊 Downloading COMMAND_REFERENCE.txt..."
curl -L https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/COMMAND_REFERENCE.txt -o ~/.local/waveproxy/COMMAND_REFERENCE.txt
echo -e "${GREEN}🌊 COMMAND_REFERENCE.txt downloaded successfully${NC}"

# 9. 配置 PATH
if ! echo "$PATH" | grep -q "$HOME/.local/waveproxy/bin"; then
    echo 'export PATH="$HOME/.local/waveproxy/bin:$PATH"' >> ~/.bashrc
    echo 'export PATH="$HOME/.local/waveproxy/bin:$PATH"' >> ~/.zshrc
    echo -e "${GREEN}🌊 PATH updated${NC}"
fi

# ====== 协议确认机制 ======
echo ""
echo -e "${YELLOW}Please read the agreement before use (see bottom of https://proxy.macwave.org).${NC}"
read -p "Have you read and agreed to the agreement? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🌊 You have agreed to the agreement. Installation continues.${NC}"
else
    echo -e "${RED}🌊 You do not agree to the agreement. Installation stopped.${NC}"
    exit 1
fi
# =========================

echo ""
echo -e "${GREEN}🌊 WaveProxy v1.0.0 installation complete!${NC}"
echo ""
echo -e "${GREEN}🌊 Quick start:${NC}"
echo "  waveproxy query github.com          # Query proxy for a URL"
echo "  proxywrap curl -LO <url>            # Auto-proxy download"
echo "  proxydeploy                         # Show current default config name"
echo ""
echo -e "${GREEN}🌊 Config file: ~/.local/waveproxy/proxydeploy@default.txt${NC}"
echo -e "${YELLOW}🌊 Tip: Run 'source ~/.zshrc' or restart your terminal to use waveproxy immediately.${NC}"
