# frozen_string_literal: true

class Matcher
  def initialize
    @regex_cache = {}
  end

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

  def resolve(url, variables, blocks, verbose = false)
    puts "🌊 [verbose] Resolving URL: #{url}" if verbose

    blocks.each_with_index do |block, i|
      puts "🌊 [verbose] Checking block ##{i + 1}: #{block.proxy_var}" if verbose

      block.direct_rules.each do |direct_pattern|
        if match_pattern(url, direct_pattern)
          puts "🌊 [verbose] → Direct match: #{direct_pattern}" if verbose
          return nil
        end
      end

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
          if unless_matched
            puts "🌊 [verbose] → Excluded but whitelisted by: #{exclude.unless_list}" if verbose
          else
            puts "🌊 [verbose] → Excluded by: #{exclude.pattern}" if verbose
            excluded = true
            break
          end
        end
      end
      next if excluded

      block.patterns.each do |pattern|
        if match_pattern(url, pattern)
          puts "🌊 [verbose] → Matched: #{pattern} -> #{block.proxy_var}" if verbose
          return variables[block.proxy_var]
        end
      end

      if block.alt_fallback
        puts "🌊 [verbose] → Using fallback: #{block.alt_fallback}" if verbose
        return variables[block.alt_fallback]
      end

      if block.fallback
        puts "🌊 [verbose] → Using default: #{block.fallback}" if verbose
        return variables[block.fallback]
      end
    end

    puts "🌊 [verbose] → No match, returning None" if verbose
    nil
  end
end
