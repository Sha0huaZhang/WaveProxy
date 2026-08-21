#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'
require 'uri'
require_relative '../lib/parser'
require_relative '../lib/matcher'

VERSION = "1.0.0"
HOME = Pathname.new(Dir.home)
CONFIG_DIR = HOME.join('.local', 'waveproxy')

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
  puts "  \033[32m-f, --fail\033[0m          Exit with non-zero code on error (like curl -f)"
  puts
  puts "For more details, visit: \033[34mhttps://proxy.macwave.org\033[0m"
end

def print_help_all
  # 蓝色等号居中标题，两边等号数量一致
  puts
  puts "\033[34m============waveproxy (proxy decision engine)============\033[0m"
  puts
  print_help
  puts

  puts "\033[34m============proxydeploy (configuration management)============\033[0m"
  puts
  system('proxydeploy -h 2>/dev/null') || puts("🌊 proxydeploy command not found.")
  puts

  puts
  puts "\033[34m============proxywrap (auto-inject wrapper)============\033[0m"
  puts
  system('proxywrap -h 2>/dev/null') || puts("🌊 proxywrap command not found.")
end

def main
  if ARGV.empty?
    puts "Usage: waveproxy query <url>"
    exit 1
  end

  if ARGV.include?('-V') || ARGV.include?('--version')
    puts "WaveProxy #{VERSION} 🌊"
    exit 0
  end

  if ARGV.include?('-h') || ARGV.include?('--help')
    print_help
    exit 0
  end

  if ARGV.include?('--help-all')
    print_help_all
    exit 0
  end

  # 检查 --once 参数（作用于本次查询本身）
  if ARGV.include?('--once')
    ARGV.delete('--once')
    # 标记本次查询为单次模式，供后续逻辑使用
    # 实际单次行为由环境变量或内部逻辑控制
  end

  fail_on_error = false
  if ARGV.include?('-f') || ARGV.include?('--fail')
    fail_on_error = true
    ARGV.delete('-f')
    ARGV.delete('--fail')
  end

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

  verbose = false
  if ARGV.include?('-v') || ARGV.include?('--verbose')
    verbose = true
    ARGV.delete('-v')
    ARGV.delete('--verbose')
  end

  silent = false
  if ARGV.include?('-s') || ARGV.include?('--silent')
    silent = true
    ARGV.delete('-s')
    ARGV.delete('--silent')
  end

  if ARGV[0] != 'query'
    puts "Usage: waveproxy query <url>"
    exit 1 if fail_on_error
    exit 1
  end

  url = ARGV[1]
  if url.nil? || url.empty?
    $stderr.puts "Usage: waveproxy query <url>"
    exit 1 if fail_on_error
    exit 1
  end

  begin
    URI.parse(url)
  rescue URI::InvalidURIError
    $stderr.puts "Error: invalid URL '#{url}'"
    exit 1 if fail_on_error
    exit 1
  end

  puts "🌊 [verbose] Querying URL: #{url}" if verbose

  # --- 处理单次强制/忽略（通过环境变量） ---
  once_enforce_config = ENV['WAVEPROXY_ONCE_ENFORCE_CONFIG']
  once_enforce_proxy = ENV['WAVEPROXY_ONCE_ENFORCE_PROXY']
  once_ignore_config = ENV['WAVEPROXY_ONCE_IGNORE_CONFIG']
  once_ignore_proxy = ENV['WAVEPROXY_ONCE_IGNORE_PROXY']

  # --- 处理长期强制/忽略（会话级） ---
  enforce_config = ENV['WAVEPROXY_ENFORCE_CONFIG']
  enforce_proxy = ENV['WAVEPROXY_ENFORCE_PROXY']
  ignore_config = ENV['WAVEPROXY_IGNORE_CONFIG']
  ignore_proxy = ENV['WAVEPROXY_IGNORE_PROXY']

  # 如果有单次强制配置，覆盖 config_name 并清空变量
  if once_enforce_config
    config_name = once_enforce_config
    ENV['WAVEPROXY_ONCE_ENFORCE_CONFIG'] = nil
    puts "🌊 [verbose] Once-enforced config: #{config_name}" if verbose
  elsif once_enforce_proxy
    proxy = once_enforce_proxy
    ENV['WAVEPROXY_ONCE_ENFORCE_PROXY'] = nil
    puts "🌊 [verbose] Once-enforced proxy: #{proxy}" if verbose
    puts "\"#{proxy}\""
    exit 0
  elsif once_ignore_config
    ignore_config_name = once_ignore_config
    ENV['WAVEPROXY_ONCE_IGNORE_CONFIG'] = nil
    puts "🌊 [verbose] Once-ignored config: #{ignore_config_name}" if verbose
    puts "None"
    exit 0
  elsif once_ignore_proxy
    ignore_proxy_addr = once_ignore_proxy
    ENV['WAVEPROXY_ONCE_IGNORE_PROXY'] = nil
    puts "🌊 [verbose] Once-ignored proxy: #{ignore_proxy_addr}" if verbose
    # 由后续匹配逻辑处理
  end

  # 如果有会话级强制代理，直接返回
  if enforce_proxy
    puts "🌊 [verbose] Proxy enforced via ENV: #{enforce_proxy}" if verbose
    puts "\"#{enforce_proxy}\""
    exit 0
  end

  # 如果有会话级强制配置，覆盖 config_name
  if enforce_config
    config_name = enforce_config
    puts "🌊 [verbose] Config enforced via ENV: #{config_name}" if verbose
  end

  # 加载配置
  variables, blocks, errors = load_config(verbose)

  # 如果有会话级忽略配置且与当前 config_name 一致，直连
  if ignore_config && config_name == ignore_config
    puts "🌊 [verbose] Config ignored via ENV: #{ignore_config}" if verbose
    puts "None"
    exit 0
  end

  unless errors.empty?
    errors.each { |err| $stderr.puts err }
    exit 1 if fail_on_error
    exit 1
  end

  if blocks.empty?
    puts "🌊 [verbose] No rules found, returning None" if verbose
    puts "🌊 None"
    exit 0
  end

  matcher = Matcher.new
  result = matcher.resolve(url, variables, blocks, verbose)

  # 如果匹配结果等于会话级忽略代理，则返回 None
  if ignore_proxy && result == ignore_proxy
    puts "🌊 [verbose] Proxy ignored via ENV: #{ignore_proxy}" if verbose
    puts "None"
    exit 0
  end

  # 如果匹配结果等于单次忽略代理，则返回 None
  if once_ignore_proxy && result == once_ignore_proxy
    puts "🌊 [verbose] Once-ignored proxy matched: #{once_ignore_proxy}" if verbose
    puts "None"
    exit 0
  end

  if result.nil?
    puts "🌊 None"
  else
    puts "🌊 \"#{result}\""
  end
end

main if __FILE__ == $0
