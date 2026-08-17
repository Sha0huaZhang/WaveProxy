#!/usr/bin/env python3
"""
WaveProxy - 命令行代理决策工具
配置文件：~/.local/waveproxy/proxydeploy@名称.txt
用法：
    waveproxy query <url>          # 查询代理
"""

import sys
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple


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


class ProxyParser:
    """配置文件解析器"""
    def __init__(self):
        self.variables: Dict[str, str] = {}
        self.blocks: List[ProxyRuleBlock] = []
        self.errors: List[str] = []
        self.line_num = 0

    def parse(self, content: str) -> bool:
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
            
            if stripped.startswith('<!--'):
                if '-->' in stripped:
                    i += 1
                    continue
                while i < len(lines) and '-->' not in lines[i]:
                    i += 1
                i += 1
                continue
            
            if stripped == 'def proxy:':
                in_def_proxy = True
                i += 1
                continue
            
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
            
            if stripped == '[proxy_rule:':
                in_def_proxy = False
                i += 1
                continue
            
            if stripped == ']' and current_block:
                self.blocks.append(current_block)
                current_block = None
                i += 1
                continue
            
            if current_block:
                indent = len(line) - len(line.lstrip())
                if indent % 4 != 0:
                    self.errors.append(f"Line {self.line_num}: indentation must be multiple of 4, got {indent}")
                
                if stripped.startswith('"') and not stripped.endswith(' direct'):
                    pattern = stripped.strip('"')
                    if '*' in pattern and '**' in pattern:
                        self.errors.append(f"Line {self.line_num}: cannot use both * and ** in same proxy block")
                    current_block.patterns.append(pattern)
                
                elif stripped.startswith('! "') and ' unless ' not in stripped:
                    pattern = stripped.replace('! "', '').rstrip('"')
                    current_block.excludes.append(ExcludeRule(pattern))
                
                elif stripped.startswith('! "') and ' unless ' in stripped:
                    parts = stripped.split(' unless ')
                    pattern = parts[0].replace('! "', '').rstrip('"')
                    unless_parts = parts[1].strip()
                    unless_list = [p.strip('"') for p in unless_parts.split() if p.strip('"')]
                    if not unless_list:
                        self.errors.append(f"Line {self.line_num}: 'unless' must be followed by at least one whitelist pattern")
                    current_block.excludes.append(ExcludeRule(pattern, unless_list))
                
                elif stripped.endswith(' direct'):
                    pattern = stripped.replace(' direct', '').strip('"')
                    current_block.direct_rules.append(pattern)
                
                elif stripped.startswith('? "'):
                    name = stripped.split('"')[1]
                    if current_block.alt_fallback:
                        self.errors.append(f"Line {self.line_num}: only one '?' fallback allowed per proxy block")
                    if name not in self.variables:
                        self.errors.append(f"Line {self.line_num}: '?' references undefined variable '{name}'")
                    current_block.alt_fallback = name
                
                elif stripped.startswith('default: "'):
                    name = stripped.split('"')[1]
                    if current_block.fallback:
                        self.errors.append(f"Line {self.line_num}: only one 'default' allowed per proxy block")
                    if name not in self.variables:
                        self.errors.append(f"Line {self.line_num}: 'default' references undefined variable '{name}'")
                    current_block.fallback = name
                
                else:
                    self.errors.append(f"Line {self.line_num}: unknown keyword '{stripped}'")
            
            elif not in_def_proxy and stripped.endswith(':'):
                var_name = stripped.rstrip(':')
                if var_name in self.variables:
                    current_block = ProxyRuleBlock(var_name)
                else:
                    self.errors.append(f"Line {self.line_num}: proxy variable '{var_name}' not defined")
            
            i += 1
        
        if current_block:
            self.errors.append(f"Line {self.line_num}: unclosed proxy rule block")
        
        return len(self.errors) == 0


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
    
    def resolve(self, url: str, variables: Dict[str, str], blocks: List[ProxyRuleBlock]) -> Optional[str]:
        for block in blocks:
            for direct_pattern in block.direct_rules:
                if self.match_pattern(url, direct_pattern):
                    return None
            
            excluded = False
            for exclude in block.excludes:
                if self.match_pattern(url, exclude.pattern):
                    unless_matched = False
                    for unless_pattern in exclude.unless_list:
                        if self.match_pattern(url, unless_pattern):
                            unless_matched = True
                            break
                    if not unless_matched:
                        excluded = True
                        break
            
            if excluded:
                continue
            
            for pattern in block.patterns:
                if self.match_pattern(url, pattern):
                    return variables.get(block.proxy_var)
            
            if block.alt_fallback:
                return variables.get(block.alt_fallback)
            
            if block.fallback:
                return variables.get(block.fallback)
        
        return None


def load_config() -> Tuple[Dict[str, str], List[ProxyRuleBlock], List[str]]:
    config_name = os.environ.get('WAVEPROXY_CONFIG', 'main')
    config_path = Path.home() / '.local' / 'waveproxy' / f'proxydeploy@{config_name}.txt'
    
    if not config_path.exists():
        return {}, [], []
    
    try:
        content = config_path.read_text(encoding='utf-8')
    except Exception as e:
        return {}, [], [f"Error reading config file: {e}"]
    
    parser = ProxyParser()
    success = parser.parse(content)
    
    if not success:
        return {}, [], parser.errors
    
    return parser.variables, parser.blocks, []


def main():
    if len(sys.argv) < 2:
        print("Usage: waveproxy query <url>")
        sys.exit(1)
    
    if sys.argv[1] != 'query':
        print("Usage: waveproxy query <url>")
        sys.exit(1)
    
    url = sys.argv[2] if len(sys.argv) > 2 else None
    if not url:
        print("Usage: waveproxy query <url>")
        sys.exit(1)
    
    variables, blocks, errors = load_config()
    
    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        sys.exit(1)
    
    if not blocks:
        print("None")
        sys.exit(0)
    
    matcher = Matcher()
    result = matcher.resolve(url, variables, blocks)
    
    if result is None:
        print("None")
    else:
        print(f'"{result}"')


if __name__ == '__main__':
    main()
