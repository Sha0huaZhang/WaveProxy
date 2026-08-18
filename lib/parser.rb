# frozen_string_literal: true

require 'pathname'
require 'uri'

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

class ProxyParser
  attr_reader :variables, :blocks, :errors

  INDENT_SIZE = 4

  def initialize
    @variables = {}
    @blocks = []
    @errors = []
    @line_num = 0
  end

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

      if stripped == 'def proxy:'
        in_def_proxy = true
        i += 1
        next
      end

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

      if stripped == '[proxy_rule:'
        in_def_proxy = false
        i += 1
        next
      end

      if stripped == ']' && current_block
        @blocks << current_block
        current_block = nil
        i += 1
        next
      end

      if current_block
        indent = line.length - line.lstrip.length
        unless indent % INDENT_SIZE == 0
          @errors << "Line #{@line_num}: indentation must be multiple of #{INDENT_SIZE}, got #{indent}"
        end

        if stripped.start_with?('"') && !stripped.end_with?(' direct')
          pattern = stripped.tr('"', '')
          if pattern.include?('**')
            remaining_stars = pattern.gsub('**', '').count('*')
            if remaining_stars > 0
              @errors << "Line #{@line_num}: cannot use both * and ** in same proxy block"
            end
          end
          current_block.patterns << pattern

        elsif stripped.start_with?('! "') && !stripped.include?(' unless ')
          pattern = stripped.sub('! "', '').sub(/"$/, '')
          if pattern.include?('**')
            remaining_stars = pattern.gsub('**', '').count('*')
            if remaining_stars > 0
              @errors << "Line #{@line_num}: cannot use both * and ** in same proxy block"
            end
          end
          current_block.excludes << ExcludeRule.new(pattern)

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

        elsif stripped.end_with?(' direct')
          pattern = stripped.sub(' direct', '').tr('"', '')
          if pattern.include?('**')
            remaining_stars = pattern.gsub('**', '').count('*')
            if remaining_stars > 0
              @errors << "Line #{@line_num}: cannot use both * and ** in same proxy block"
            end
          end
          current_block.direct_rules << pattern

        elsif stripped.start_with?('? "')
          name = stripped.tr('"? ', '')
          if current_block.alt_fallback
            @errors << "Line #{@line_num}: only one '?' fallback allowed per proxy block"
          end
          unless @variables.key?(name)
            @errors << "Line #{@line_num}: '?' references undefined variable '#{name}'"
          end
          current_block.alt_fallback = name

        elsif stripped.start_with?('default: "')
          # ------------------------------废弃代码开始------------------------------------
          # 以下代码曾因使用 tr 导致变量名被误吞字符（如 "home" 变成 "hom"）。
          # 该错误在 2026 年 8 月 18 日已修复，现保留注释作为历史记录。
          # ------------------------------------------------------------------
          # 
          # 错误原因：tr('default: "', '"') 会将字符串中所有属于
          #           d, e, f, a, u, l, t, :, (空格), " 的字符都替换成 "，
          #           导致 "home" 中的 "e" 被意外替换，从而变成 "hom"。
          #
          # 错误代码（已废弃）：
          # name = stripped.tr('default: "', '"').tr('"', '')
          #
          # 修正方法：改用 sub 仅移除前缀，再用 tr 移除引号。
          # -------------------------------废弃代码结束-----------------------------------

          # 正确写法如下
          name = stripped.sub('default: "', '').tr('"', '')

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

      elsif !in_def_proxy && stripped.end_with?(':')
        label = stripped.chomp(':').tr('"', '')
        current_block = ProxyRuleBlock.new(label)
      end

      i += 1
    end

    @errors << "Line #{@line_num}: unclosed proxy rule block" if current_block
    @errors.empty?
  end
end
