#!/usr/bin/env ruby
# frozen_string_literal: true

# WaveProxy - 命令行代理决策工具
# 版本: 1.0.0
# 用法: waveproxy query <url> [flags]
# 兼容 Ruby 2.6+

require 'pathname'
require 'uri'
require 'fileutils'

VERSION = "1.0.0"
# 用户主目录
HOME = Pathname.new(Dir.home)
# 配置文件存放目录（硬编码，符合规范）
CONFIG_DIR = HOME.join('.local', 'waveproxy')
# 缩进标准（4 空格）
INDENT_SIZE = 4


# ============================================================================
# 数据结构定义
# ============================================================================

# 排除项规则（含白名单例外）
class ExcludeRule
  attr_reader :pattern, :unless_list
  def initialize(pattern, unless_list = [])
    @pattern = pattern
    @unless_list = unless_list
  end
end

# 单个代理规则块
class ProxyRuleBlock
  attr_accessor :proxy_var, :patterns, :excludes, :direct_rules, :alt_fallback, :fallback
  def initialize(proxy_var)
    @proxy_var = proxy_var
    @patterns = []
    @excludes = []
    @direct_rules = []
    @alt_fallback = nil
    @fallback = nil
  end
end


# ============================================================================
# 配置文件解析器
# ============================================================================

class ProxyParser
  attr_reader :variables, :blocks, :errors

  def initialize
    @variables = {}        # 存储 let "name" = "url" 定义的变量
    @blocks = []           # 存储解析出的规则块
    @errors = []           # 存储解析过程中的错误信息
    @line_num = 0          # 当前行号（用于错误定位）
  end

  # 解析 proxydeploy@*.txt 文件内容
  # 返回 true 表示解析成功，false 表示有错误
  def parse(content)
    lines = content.each_line.map(&:chomp)
    i = 0
    in_def_proxy = false
    current_block = nil

    while i < lines.length
      @line_num = i + 1
      line = lines[i]
      stripped = line.strip

      # 跳过空行
      if stripped.empty?
        i += 1
        next
      end

      # 跳过注释（<!-- ... -->）
      if stripped.start_with?('<!--')
        if stripped.include?('-->')
          i += 1
          next
        end
        # 处理多行注释
        while i < lines.length && !lines[i].include?('-->')
          i += 1
        end
        i += 1
        next
      end

      # 解析 def proxy: 块开始
      if stripped == 'def proxy:'
        in_def_proxy = true
        i += 1
        next
      end

      # 解析 let "name" = "url" 变量定义
      if in_def_proxy && stripped.start_with?('let ')
        match = stripped.match(/let\s+"([^"]+)"\s*=\s*"([^"]+)"/)
        if match
          name, url = match.captures
          if @variables.key?(name)
            @errors << "Line #{@line_num}: proxy variable '#{name}' already defined"
          else
            @variables[name] = url
          end
        else
          @errors << "Line #{@line_num}: invalid 'let' syntax"
        end
        i += 1
        next
      end

      # 解析 [proxy_rule: 块开始
      if stripped == '[proxy_rule:'
        in_def_proxy = false
        i += 1
        next
      end

      # 解析 ] 块结束
      if stripped == ']' && current_block
        @blocks << current_block
        current_block = nil
        i += 1
        next
      end

      # 解析规则块内的内容
      if current_block
        # 检查缩进（使用 INDENT_SIZE 常量）
        indent = line.length - line.lstrip.length
        unless indent % INDENT_SIZE == 0
          @errors << "Line #{@line_num}: indentation must be multiple of #{INDENT_SIZE}, got #{indent}"
        end

        # 解析匹配模式 "pattern"
        if stripped.start_with?('"') && !stripped.end_with?(' direct')
          pattern = stripped.tr('"', '')
          # 检查 * 和 ** 冲突
          if pattern.include?('**')
            remaining_stars = pattern.gsub('**', '').count('*')
            if remaining_stars > 0
              @errors << "Line #{@line_num}: cannot use both * and ** in same proxy block"
            end
          end
          current_block.patterns << pattern

        # 解析排除项 ! "pattern"
        elsif stripped.start_with?('! "') && !stripped.include?(' unless ')
          pattern = stripped.sub('! "', '').sub(/"$/, '')
          if pattern.include?('**')
            remaining_stars = pattern.gsub('**', '').count('*')
            if remaining_stars > 0
              @errors << "Line #{@line_num}: cannot use both * and ** in same proxy block"
            end
          end
          current_block.excludes << ExcludeRule.new(pattern)

        # 解析排除项带白名单 ! "pattern" unless "a" "b"
        elsif stripped.start_with?('! "') && stripped.include?(' unless ')
          parts = stripped.split(' unless ')
          pattern = parts[0].sub('! "', '').sub(/"$/, '')
          unless_parts = parts[1].strip
          unless_list = unless_parts.split.map { |p| p.tr('"', '') }
          if unless_list.empty?
            @errors << "Line #{@line_num}: 'unless' must be followed by at least one whitelist pattern"
          end
          if pattern.include?('**')
            remaining_stars = pattern.gsub('**', '').count('*')
            if remaining_stars > 0
              @errors << "Line #{@line_num}: cannot use both * and ** in same proxy block"
            end
          end
          current_block.excludes << ExcludeRule.new(pattern, unless_list)

        # 解析直连 "pattern" direct
        elsif stripped.end_with?(' direct')
          pattern = stripped.sub(' direct', '').tr('"', '')
          if pattern.include?('**')
            remaining_stars = pattern.gsub('**', '').count('*')
            if remaining_stars > 0
              @errors << "Line #{@line_num}: cannot use both * and ** in same proxy block"
            end
          end
          current_block.direct_rules << pattern

        # 解析备选 ? "name"
        elsif stripped.start_with?('? "')
          name = stripped.tr('"? ', '')
          if current_block.alt_fallback
            @errors << "Line #{@line_num}: only one '?' fallback allowed per proxy block"
          end
          unless @variables.key?(name)
            @errors << "Line #{@line_num}: '?' references undefined variable '#{name}'"
          end
          current_block.alt_fallback = name

        # 解析兜底 default: "name"
        elsif stripped.start_with?('default: "')
          name = stripped.tr('default: "', '"').tr('"', '')
          if current_block.fallback
            @errors << "Line #{@line_num}: only one 'default' allowed per proxy block"
          end
          unless @variables.key?(name)
            @errors << "Line #{@line_num}: 'default' references undefined variable '#{name}'"
          end
          current_block.fallback = name

        else
          @errors << "Line #{@line_num}: unknown keyword '#{stripped}'"
        end

      # 解析规则块标签（如 "home":）
      elsif !in_def_proxy && stripped.end_with?(':')
        # 修复：使用 chomp 替代 rstrip，兼容所有 Ruby 版本
        label = stripped.chomp(':').tr('"', '')
        current_block = ProxyRuleBlock.new(label)
      end

      i += 1
    end

    # 检查是否有未闭合的块
    @errors << "Line #{@line_num}: unclosed proxy rule block" if current_block

    @errors.empty?
  end
end


# ============================================================================
# URL 匹配引擎（带正则缓存）
# ============================================================================

class Matcher
  def initialize
    @regex_cache = {}
  end

  # 判断 URL 是否匹配模式（支持 * 和 **）
  def match_pattern(url, pattern)
    unless @regex_cache.key?(pattern)
      if pattern.include?('**')
        @regex_cache[pattern] = Regexp.new('^' + Regexp.escape(pattern).gsub('\\*\\*', '.*') + '$')
      elsif pattern.include?('*')
        @regex_cache[pattern] = Regexp.new('^' + Regexp.escape(pattern).gsub('\\*', '[^/]*') + '$')
      else
        @regex_cache[pattern] = pattern
      end
    end

    cached = @regex_cache[pattern]
    return url == cached if cached.is_a?(String)

    !!(url =~ cached)
  end

  # 按优先级解析 URL，返回代理地址或 nil
  def resolve(url, variables, blocks, verbose = false)
    puts "🌊 [verbose] Resolving URL: #{url}" if verbose

    blocks.each_with_index do |block, i|
      puts "🌊 [verbose] Checking block ##{i + 1}: #{block.proxy_var}" if verbose

      # 1. 检查直连
      block.direct_rules.each do |direct_pattern|
        if match_pattern(url, direct_pattern)
          puts "🌊 [verbose] → Direct match: #{direct_pattern}" if verbose
          return nil
        end
      end

      # 2. 检查排除项
      excluded = false
      block.excludes.each do |exclude|
        if match_pattern(url, exclude.pattern)
          unless_matched = false
          exclude.unless_list.each do |unless_pattern|
            if match_pattern(url, unless_pattern)
              unless_matched = true
              break
            end
          end
          unless unless_matched
            puts "🌊 [verbose] → Excluded by: #{exclude.pattern}" if verbose
            excluded = true
            break
          else
            puts "🌊 [verbose] → Excluded but whitelisted by: #{exclude.unless_list}" if verbose
          end
        end
      end
      next if excluded

      # 3. 检查匹配模式
      block.patterns.each do |pattern|
        if match_pattern(url, pattern)
          puts "🌊 [verbose] → Matched: #{pattern} -> #{block.proxy_var}" if verbose
          return variables[block.proxy_var]
        end
      end

      # 4. 检查备选
      if block.alt_fallback
        puts "🌊 [verbose] → Using fallback: #{block.alt_fallback}" if verbose
        return variables[block.alt_fallback]
      end

      # 5. 检查兜底
      if block.fallback
        puts "🌊 [verbose] → Using default: #{block.fallback}" if verbose
        return variables[block.fallback]
      end
    end

    puts "🌊 [verbose] → No match, returning None" if verbose
    nil
  end
end


# ============================================================================
# 配置文件加载器
# ============================================================================

# 加载并解析配置文件，返回变量、规则块和错误列表
def load_config(verbose = false)
  config_name = ENV['WAVEPROXY_CONFIG'] || 'default'
  config_path = CONFIG_DIR + "proxydeploy@#{config_name}.txt"

  puts "🌊 [verbose] Using config: #{config_path}" if verbose

  unless config_path.exist?
    puts "🌊 [verbose] Config file not found, using no rules" if verbose
    return [{}, [], []]
  end

  begin
    content = config_path.read
  rescue => e
    return [{}, [], ["Error reading config file: #{e.message}"]]
  end

  parser = ProxyParser.new
  success = parser.parse(content)

  unless success
    return [{}, [], parser.errors]
  end

  puts "🌊 [verbose] Loaded #{parser.variables.size} variables, #{parser.blocks.size} rule blocks" if verbose

  [parser.variables, parser.blocks, parser.errors]
end


# ============================================================================
# 帮助与主程序
# ============================================================================

# 打印帮助信息（含颜色）
def print_help
  puts "\033[35musage: \033[38;5;197mwaveproxy <command> [url] [flags]\033[0m"
  puts
  puts "WaveProxy #{VERSION} 🌊"
  puts "A lightweight, script-friendly command-line proxy decision tool."
  puts
  puts "\033[35mCommands:\033[0m"
  puts "  \033[32mquery <url>\033[0m          Query the proxy for a given URL"
  puts "                          Output: \"proxy\" or None"
  puts "  \033[32mcommandreference\033[0m     Print the complete command reference"
  puts
  puts "\033[35mFlags:\033[0m"
  puts "  \033[32m-h, --help\033[0m          Show this help message and exit"
  puts "  \033[32m-V, --version\033[0m       Show program's version number and exit"
  puts "  \033[32m-s, --silent\033[0m        Suppress all non-output messages (for scripting)"
  puts "  \033[32m-v, --verbose\033[0m       Enable detailed debug output (stderr)"
  puts "  \033[32m-f, --fail\033[0m           Exit with non-zero code on error (like curl -f)"
  puts
  puts "For more details, visit: https://proxy.macwave.org"
end

# 主程序入口
def main
  # 如果没有参数，显示用法并退出
  if ARGV.empty?
    puts "Usage: waveproxy query <url>"
    exit 1
  end

  # 检查 -V / --version
  if ARGV.include?('-V') || ARGV.include?('--version')
    puts "WaveProxy #{VERSION} 🌊"
    exit 0
  end

  # 检查 -h / --help
  if ARGV.include?('-h') || ARGV.include?('--help')
    print_help
    exit 0
  end

  # 检查 -f / --fail
  fail_on_error = false
  if ARGV.include?('-f') || ARGV.include?('--fail')
    fail_on_error = true
    ARGV.delete('-f')
    ARGV.delete('--fail')
  end

  # 检查 commandreference 子命令
  if ARGV[0] == 'commandreference'
    ref_path = CONFIG_DIR + 'COMMAND_REFERENCE.txt'
    if ref_path.exist?
      puts ref_path.read
    else
      $stderr.puts "Error: COMMAND_REFERENCE.txt not found."
      exit 1 if fail_on_error
    end
    exit 0
  end

  # 检查 -v / --verbose
  verbose = false
  if ARGV.include?('-v') || ARGV.include?('--verbose')
    verbose = true
    ARGV.delete('-v')
    ARGV.delete('--verbose')
  end

  # 检查 -s / --silent
  silent = false
  if ARGV.include?('-s') || ARGV.include?('--silent')
    silent = true
    ARGV.delete('-s')
    ARGV.delete('--silent')
  end

  # 如果不是 query 命令，报错并退出
  if ARGV[0] != 'query'
    puts "Usage: waveproxy query <url>"
    exit 1 if fail_on_error
    exit 1
  end

  # 获取 URL 参数
  url = ARGV[1]
  if url.nil? || url.empty?
    $stderr.puts "Usage: waveproxy query <url>"
    exit 1 if fail_on_error
    exit 1
  end

  # 验证 URL 格式（安全措施）
  begin
    URI.parse(url)
  rescue URI::InvalidURIError
    $stderr.puts "Error: invalid URL '#{url}'"
    exit 1 if fail_on_error
    exit 1
  end

  puts "🌊 [verbose] Querying URL: #{url}" if verbose

  # 加载配置文件
  variables, blocks, errors = load_config(verbose)

  # 如果有错误，输出错误信息并按 -f 决定退出码
  unless errors.empty?
    errors.each { |err| $stderr.puts err }
    exit 1 if fail_on_error
    exit 1
  end

  # 如果没有规则块，返回 None
  if blocks.empty?
    puts "🌊 [verbose] No rules found, returning None" if verbose
    puts "None"
    exit 0
  end

  # 匹配 URL
  matcher = Matcher.new
  result = matcher.resolve(url, variables, blocks, verbose)

  # 输出结果
  if result.nil?
    puts "None"
  else
    puts "\"#{result}\""
  end
end

# 执行主程序
main if __FILE__ == $0
