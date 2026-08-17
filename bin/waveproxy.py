#!/usr/bin/env python3
"""
WaveProxy - 命令行代理决策工具
配置文件：~/.local/waveproxy/proxydeploy@名称.txt
用法：
    waveproxy query <url>          # 查询代理
    waveproxy commandreference     # 查看完整命令参考
"""

import sys
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ==================== proxydeploy 数据结构定义 开始 ====================

class ExcludeRule:
    """排除项规则（含白名单例外）"""
    def __init__(self, pattern: str, unless_list: List[str] = None):
        self.pattern = pattern
        self.unless_list = unless_list or []


class ProxyRuleBlock:
    """单个代理规则块"""
    def __init__(self, proxy_var: str):
        self.proxy_var = proxy_var
        self.patterns: List[str] = []
        self.excludes: List[ExcludeRule] = []
        self.direct_rules: List[str] = []
        self.alt_fallback: Optional[str] = None
        self.fallback: Optional[str] = None

# ==================== proxydeploy 数据结构定义 结束 ====================


class ProxyParser:
    """配置文件解析器"""
    def __init__(self):
        self.variables: Dict[str, str] = {}
        self.blocks: List[ProxyRuleBlock] = []
        self.errors: List[str] = []
        self.line_num = 0

    # ==================== 解析 proxydeploy@*.txt 开始 ====================
    def parse(self, content: str) -> bool:
        """解析配置文件内容，返回是否解析成功"""
        lines = content.split('\n')
        i = 0
        in_def_proxy = False
        current_block: Optional[ProxyRuleBlock] = None
        
        while i < len(lines):
            self.line_num = i + 1
            line = lines[i].rstrip('\n')
            stripped = line.strip()
            
            if not stripped:
                i += 1
                continue
            
            # 跳过注释（<!-- ... -->）
            if stripped.startswith('<!--'):
                if '-->' in stripped:
                    i += 1
                    continue
                while i < len(lines) and '-->' not in lines[i]:
                    i += 1
                i += 1
                continue
            
            # 解析 def proxy: 块
            if stripped == 'def proxy:':
                in_def_proxy = True
                i += 1
                continue
            
            # 解析 let "name" = "url"
            if in_def_proxy and stripped.startswith('let '):
                match = re.match(r'let\s+"([^"]+)"\s*=\s*"([^"]+)"', stripped)
                if match:
                    name, url = match.groups()
                    if name in self.variables:
                        self.errors.append(f"Line {self.line_num}: proxy variable '{name}' already defined")
                    else:
                        self.variables[name] = url
                else:
                    self.errors.append(f"Line {self.line_num}: invalid 'let' syntax")
                i += 1
                continue
            
            # 解析 [proxy_rule: 开始
            if stripped == '[proxy_rule:':
                in_def_proxy = False
                i += 1
                continue
            
            # 解析 ] 结束块
            if stripped == ']' and current_block:
                self.blocks.append(current_block)
                current_block = None
                i += 1
                continue
            
            # 解析规则块内的内容
            if current_block:
                # 检查缩进（必须是 4 的倍数）
                indent = len(line) - len(line.lstrip())
                if indent % 4 != 0:
                    self.errors.append(f"Line {self.line_num}: indentation must be multiple of 4, got {indent}")
                
                # 解析匹配模式 "pattern"
                if stripped.startswith('"') and not stripped.endswith(' direct'):
                    pattern = stripped.strip('"')
                    if '*' in pattern and '**' in pattern:
                        self.errors.append(f"Line {self.line_num}: cannot use both * and ** in same proxy block")
                    current_block.patterns.append(pattern)
                
                # 解析排除项 ! "pattern"
                elif stripped.startswith('! "') and ' unless ' not in stripped:
                    pattern = stripped.replace('! "', '').rstrip('"')
                    current_block.excludes.append(ExcludeRule(pattern))
                
                # 解析排除项带白名单 ! "pattern" unless "a" "b"
                elif stripped.startswith('! "') and ' unless ' in stripped:
                    parts = stripped.split(' unless ')
                    pattern = parts[0].replace('! "', '').rstrip('"')
                    unless_parts = parts[1].strip()
                    unless_list = [p.strip('"') for p in unless_parts.split() if p.strip('"')]
                    if not unless_list:
                        self.errors.append(f"Line {self.line_num}: 'unless' must be followed by at least one whitelist pattern")
                    current_block.excludes.append(ExcludeRule(pattern, unless_list))
                
                # 解析直连 "pattern" direct
                elif stripped.endswith(' direct'):
                    pattern = stripped.replace(' direct', '').strip('"')
                    current_block.direct_rules.append(pattern)
                
                # 解析备选 ? "name"
                elif stripped.startswith('? "'):
                    name = stripped.split('"')[1]
                    if current_block.alt_fallback:
                        self.errors.append(f"Line {self.line_num}: only one '?' fallback allowed per proxy block")
                    if name not in self.variables:
                        self.errors.append(f"Line {self.line_num}: '?' references undefined variable '{name}'")
                    current_block.alt_fallback = name
                
                # 解析兜底 default: "name"
                elif stripped.startswith('default: "'):
                    name = stripped.split('"')[1]
                    if current_block.fallback:
                        self.errors.append(f"Line {self.line_num}: only one 'default' allowed per proxy block")
                    if name not in self.variables:
                        self.errors.append(f"Line {self.line_num}: 'default' references undefined variable '{name}'")
                    current_block.fallback = name
                
                # 未知关键字
                else:
                    self.errors.append(f"Line {self.line_num}: unknown keyword '{stripped}'")
            
            # 修复：解析规则块标签
            elif not in_def_proxy and stripped.endswith(':'):
                # 去掉冒号和引号，得到块标签
                label = stripped.rstrip(':').strip('"')
                # 直接创建规则块，不需要检查变量是否存在
                current_block = ProxyRuleBlock(label)
            
            i += 1
        
        # 检查是否有未闭合的块
        if current_block:
            self.errors.append(f"Line {self.line_num}: unclosed proxy rule block")
        
        return len(self.errors) == 0
    # ==================== 解析 proxydeploy@*.txt 结束 ====================


class Matcher:
    """URL 匹配引擎"""
    
    @staticmethod
    def match_pattern(url: str, pattern: str) -> bool:
        if '**' in pattern:
            regex = re.escape(pattern).replace(r'\*\*', '.*')
            regex = f'^{regex}$'
            return re.match(regex, url) is not None
        
        if '*' in pattern:
            regex = re.escape(pattern).replace(r'\*', r'[^/]*')
            regex = f'^{regex}$'
            return re.match(regex, url) is not None
        
        return url == pattern
    
    def resolve(self, url: str, variables: Dict[str, str], blocks: List[ProxyRuleBlock], verbose=False) -> Optional[str]:
        if verbose:
            print(f"🌊 [verbose] Resolving URL: {url}", file=sys.stderr)
        
        for i, block in enumerate(blocks):
            if verbose:
                print(f"🌊 [verbose] Checking block #{i+1}: {block.proxy_var}", file=sys.stderr)
            
            # 1. 检查直连
            for direct_pattern in block.direct_rules:
                if self.match_pattern(url, direct_pattern):
                    if verbose:
                        print(f"🌊 [verbose] → Direct match: {direct_pattern}", file=sys.stderr)
                    return None
            
            # 2. 检查排除项
            excluded = False
            for exclude in block.excludes:
                if self.match_pattern(url, exclude.pattern):
                    unless_matched = False
                    for unless_pattern in exclude.unless_list:
                        if self.match_pattern(url, unless_pattern):
                            unless_matched = True
                            break
                    if not unless_matched:
                        if verbose:
                            print(f"🌊 [verbose] → Excluded by: {exclude.pattern}", file=sys.stderr)
                        excluded = True
                        break
                    else:
                        if verbose:
                            print(f"🌊 [verbose] → Excluded but whitelisted by: {exclude.unless_list}", file=sys.stderr)
            
            if excluded:
                continue
            
            # 3. 检查匹配模式
            for pattern in block.patterns:
                if self.match_pattern(url, pattern):
                    if verbose:
                        print(f"🌊 [verbose] → Matched: {pattern} -> {block.proxy_var}", file=sys.stderr)
                    return variables.get(block.proxy_var)
            
            # 4. 检查备选
            if block.alt_fallback:
                if verbose:
                    print(f"🌊 [verbose] → Using fallback: {block.alt_fallback}", file=sys.stderr)
                return variables.get(block.alt_fallback)
            
            # 5. 检查兜底
            if block.fallback:
                if verbose:
                    print(f"🌊 [verbose] → Using default: {block.fallback}", file=sys.stderr)
                return variables.get(block.fallback)
        
        if verbose:
            print(f"🌊 [verbose] → No match, returning None", file=sys.stderr)
        return None


# ==================== 加载 proxydeploy@*.txt 开始 ====================

def load_config(verbose=False) -> Tuple[Dict[str, str], List[ProxyRuleBlock], List[str]]:
    # 默认配置名改为 default
    config_name = os.environ.get('WAVEPROXY_CONFIG', 'default')
    config_path = Path.home() / '.local' / 'waveproxy' / f'proxydeploy@{config_name}.txt'
    
    if verbose:
        print(f"🌊 [verbose] Using config: {config_path}", file=sys.stderr)
    
    if not config_path.exists():
        if verbose:
            print(f"🌊 [verbose] Config file not found, using no rules", file=sys.stderr)
        return {}, [], []
    
    try:
        content = config_path.read_text(encoding='utf-8')
    except Exception as e:
        return {}, [], [f"Error reading config file: {e}"]
    
    parser = ProxyParser()
    success = parser.parse(content)
    
    if not success:
        return {}, [], parser.errors
    
    if verbose:
        print(f"🌊 [verbose] Loaded {len(parser.variables)} variables, {len(parser.blocks)} rule blocks", file=sys.stderr)
    
    return parser.variables, parser.blocks, []

# ==================== 加载 proxydeploy@*.txt 结束 ====================


def print_waveproxy_help():
    print("\033[35musage: \033[38;5;197mwaveproxy <command> [url] [flags]\033[0m")
    print()
    print("WaveProxy 1.0.0 🌊")
    print("A lightweight, script-friendly command-line proxy decision tool.")
    print()
    print("\033[35mCommands:\033[0m")
    print("  \033[32mquery <url>\033[0m          Query the proxy for a given URL")
    print("                          Output: \"proxy\" or None")
    print("  \033[32mcommandreference\033[0m     Print the complete command reference")
    print()
    print("\033[35mFlags:\033[0m")
    print("  \033[32m-h, --help\033[0m          Show this help message and exit")
    print("  \033[32m-V, --version\033[0m       Show program's version number and exit")
    print("  \033[32m-s, --silent\033[0m        Suppress all non-output messages (for scripting)")
    print("  \033[32m-v, --verbose\033[0m       Enable detailed debug output (stderr)")
    print()
    print("For more details, visit: https://waveproxy.org")


def main():
    if len(sys.argv) < 2:
        print("Usage: waveproxy query <url>")
        sys.exit(1)

    # 检查 -V / --version
    if '-V' in sys.argv or '--version' in sys.argv:
        print("WaveProxy 1.0.0 🌊")
        sys.exit(0)

    # 检查 -h / --help
    if '-h' in sys.argv or '--help' in sys.argv:
        print_waveproxy_help()
        sys.exit(0)

    # 检查 commandreference 子命令
    if sys.argv[1] == 'commandreference':
        ref_path = Path.home() / '.local' / 'waveproxy' / 'COMMAND_REFERENCE.txt'
        if ref_path.exists():
            print(ref_path.read_text())
        else:
            print("Error: COMMAND_REFERENCE.txt not found.")
        sys.exit(0)

    # 检查 -v / --verbose
    verbose = False
    if '-v' in sys.argv or '--verbose' in sys.argv:
        verbose = True
        sys.argv = [arg for arg in sys.argv if arg not in ('-v', '--verbose')]

    # 检查 -s / --silent
    silent = False
    if '-s' in sys.argv or '--silent' in sys.argv:
        silent = True
        sys.argv = [arg for arg in sys.argv if arg not in ('-s', '--silent')]

    if sys.argv[1] != 'query':
        print("Usage: waveproxy query <url>")
        sys.exit(1)

    url = sys.argv[2] if len(sys.argv) > 2 else None
    if not url:
        print("Usage: waveproxy query <url>")
        sys.exit(1)

    if verbose:
        print(f"🌊 [verbose] Querying URL: {url}", file=sys.stderr)

    variables, blocks, errors = load_config(verbose=verbose)

    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        sys.exit(1)

    if not blocks:
        if verbose:
            print(f"🌊 [verbose] No rules found, returning None", file=sys.stderr)
        print("None")
        sys.exit(0)

    matcher = Matcher()
    result = matcher.resolve(url, variables, blocks, verbose=verbose)

    if result is None:
        print("None")
    else:
        print(f'"{result}"')


if __name__ == '__main__':
    main()
