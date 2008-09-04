#--
# This patch fixes some formatting errors in OptParse.
# In particular, long config names and config names of
# 13 characters in length cause either ugly wrapping,
# or an outright error.  It could also wrap long comments,
# although that feature is currently disabled.
#
# See:
# - http://bahuvrihi.lighthouseapp.com/projects/9908/tickets/97-unlucky-13-character-config-name#ticket-97-1

class OptionParser # :nodoc:
  class Switch # :nodoc:
    undef_method :summarize
    
    def summarize(sdone = [], ldone = [], width = 1, max = width - 1, indent = "")
      sopts, lopts = [], []
      @short.each {|s| sdone.fetch(s) {sopts << s}; sdone[s] = true} if @short
      @long.each {|s| ldone.fetch(s) {lopts << s}; ldone[s] = true} if @long
      return if sopts.empty? and lopts.empty? # completely hidden

      left = [sopts.join(', ')]
      right = desc.dup

      while str = lopts.shift
        l = left[-1].length + str.length
        l += arg.length if left.size == 1 && arg
        #l < max or left << ''
        left[-1] << if left[-1].empty? then ' ' * 4 else ', ' end << str
      end

      #left[0] << arg if arg
      left[-1] << arg if arg

      mlen = left.collect {|s| s.length}.max.to_i
      while mlen > width and l = left.shift
        mlen = left.collect {|s| s.length}.max.to_i if l.length == mlen
        yield(indent + l)
      end

      # uncomment to justify long comments
      # comment_indent = width + indent.length + 2
      # split_right = []
      # right.each do |obj|
      #   start_index = 0
      #   str = obj.to_str
      #   while start_index < str.length
      #     split_right << str[start_index, comment_indent].strip
      #     start_index += comment_indent
      #   end
      # end
      # right = split_right

      while begin l = left.shift; r = right.shift; l or r end
        l = l.to_s.ljust(width) + ' ' + r if r and !r.empty?
        #yield(indent + l)
        yield(indent + l) unless l == nil
      end

      self
    end
  end
end