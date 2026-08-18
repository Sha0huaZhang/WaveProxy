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
  puts "WaveProxy #{VERSION} 🌊"
  puts "A lightweight, script-friendly command-line proxy decision tool."
  puts "\033[35mCommands:\033[0m"
  puts "  \033[32mquery <url>\033[0m          Query the proxy for a given URL"
  puts "                          Output: \"proxy\" or None"
  puts "  \033[32mcommandreference\033[0m     Print the complete command reference"
  puts "\033[35mFlags:\033[0m"
  puts "  \033[32m-h, --help\033[0m          Show this help message and exit"
  puts "  \033[32m-V, --version\033[0m       Show program's version number and exit"
  puts "  \033[32m-s, --silent\033[0m        Suppress all non-output messages (for scripting)"
  puts "  \033[32m-v, --verbose\033[0m       Enable detailed debug output (stderr)"
  puts "  \033[32m-f, --fail\033[0m           Exit with non-zero code on error (like curl -f)"
  puts "For more details, visit: https://proxy.macwave.org"
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

  variables, blocks, errors = load_config(verbose)

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

  if result.nil?
    puts "🌊 None"
  else
    puts "🌊 \"#{result}\""
  end
end

main if __FILE__ == $0
