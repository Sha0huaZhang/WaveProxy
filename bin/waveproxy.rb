#!/usr/bin/env ruby
# WaveProxy - Ruby 版
# 用法: waveproxy-rb query <url>

require 'pathname'
require 'uri'
require 'fileutils'

VERSION = "1.0.0"
HOME = Pathname.new(Dir.home)
CONFIG_DIR = HOME + '.local' / 'waveproxy'

# ==================== 数据结构定义 开始 ====================

class ExcludeRule
  attr_reader :pattern, :unless_list
  def initialize(pattern, unless_list = [])
    @pattern = pattern
    @unless_list = unless_list
  end
end

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

# ==================== 数据结构定义 结束 ====================


class ProxyParser
  attr_reader :variables, :blocks, :errors

  def initialize
    @variables = {}
    @blocks = []
    @errors = []
    @line_num = 0
  end

  # ==================== 解析 proxydeploy@*.txt 开始 ====================
  def parse(content)
    lines = content.each_line.map(&:chomp)
    i = 0
    in_def_proxy = false
    current_block = nil

    while i < lines.length
      @line_num = i + 1
      line = lines[i]
      stripped = line.strip

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
        while i < lines.length && !lines[i].include?('-->')
          i += 1
        end
        i += 1
        next
      end

      # 解析 def proxy: 块
      if stripped == 'def proxy:'
        in_def_proxy = true
        i += 1
        next
      end

      # 解析 let "name" = "url"
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

      # 解析 [proxy_rule: 开始
      if stripped == '[proxy_rule:'
        in_def_proxy = false
        i += 1
        next
      end

      # 解析 ] 结束块
      if stripped == ']' && current_block
        @blocks << current_block
        current_block = nil
        i += 1
        next
      end

      # 解析规则块内的内容
      if current_block
        # 检查缩进（必须是 4 的倍数）
        indent = line.length - line.lstrip.length
        unless indent % 4 == 0
          @errors << "Line #{@line_num}: indentation must be multiple of 4, got #{indent}"
        end

        # 解析匹配模式 "pattern"
        if stripped.start_with?('"') && !stripped.end_with?(' direct')
          pattern = stripped.tr('"', '')
          # 修复：正确判断 * 和 ** 冲突
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

      # 解析规则块标签
      elsif !in_def_proxy && stripped.end_with?(':')
        label = stripped.rstrip(':').tr('"', '')
        current_block = ProxyRuleBlock.new(label)
      end

      i += 1
    end

    @errors << "Line #{@line_num}: unclosed proxy rule block" if current_block

    @errors.empty?
  end
  # ==================== 解析 proxydeploy@*.txt 结束 ====================
end


class Matcher
  def match_pattern(url, pattern)
    if pattern.include?('**')
      regex = Regexp.new('^' + Regexp.escape(pattern).gsub('\\*\\*', '.*') + '$')
      return !!(url =~ regex)
    end

    if pattern.include?('*')
      regex = Regexp.new('^' + Regexp.escape(pattern).gsub('\\*', '[^/]*') + '$')
      return !!(url =~ regex)
    end

    url == pattern
  end

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


# ==================== 加载 proxydeploy@*.txt 开始 ====================

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

# ==================== 加载 proxydeploy@*.txt 结束 ====================


def print_help
  puts "\033[35musage: \033[38;5;197mwaveproxy-rb <command> [url] [flags]\033[0m"
  puts
  puts "WaveProxy #{VERSION} 🌊 (Ruby)"
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
  puts
  puts "For more details, visit: https://waveproxy.org"
end


def main
  if ARGV.empty?
    puts "Usage: waveproxy-rb query <url>"
    exit 1
  end

  # 检查 -V / --version
  if ARGV.include?('-V') || ARGV.include?('--version')
    puts "WaveProxy #{VERSION} 🌊 (Ruby)"
    exit 0
  end

  # 检查 -h / --help
  if ARGV.include?('-h') || ARGV.include?('--help')
    print_help
    exit 0
  end

  # 检查 commandreference 子命令
  if ARGV[0] == 'commandreference'
    ref_path = CONFIG_DIR + 'COMMAND_REFERENCE.txt'
    if ref_path.exist?
      puts ref_path.read
    else
      puts "Error: COMMAND_REFERENCE.txt not found."
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

  if ARGV[0] != 'query'
    puts "Usage: waveproxy-rb query <url>"
    exit 1
  end

  url = ARGV[1]
  if url.nil? || url.empty?
    puts "Usage: waveproxy-rb query <url>"
    exit 1
  end

  puts "🌊 [verbose] Querying URL: #{url}" if verbose

  variables, blocks, errors = load_config(verbose)

  unless errors.empty?
    errors.each { |err| puts err }
    exit 1
  end

  if blocks.empty?
    puts "🌊 [verbose] No rules found, returning None" if verbose
    puts "None"
    exit 0
  end

  matcher = Matcher.new
  result = matcher.resolve(url, variables, blocks, verbose)

  if result.nil?
    puts "None"
  else
    puts "\"#{result}\""
  end
end

main if __FILE__ == $0
