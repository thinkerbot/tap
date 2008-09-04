class OptionParser
  class Switch
    def summarize(sdone = [], ldone = [], width = 1, max = width - 1, indent = "")
      sopts, lopts, s = [], [], nil
      @short.each {|s| sdone.fetch(s) {sopts << s}; sdone[s] = true} if @short
      @long.each {|s| ldone.fetch(s) {lopts << s}; ldone[s] = true} if @long
      return if sopts.empty? and lopts.empty? # completely hidden
      
      left = [sopts.join(', ')]
      right = desc.dup

      while s = lopts.shift
        l = left[-1].length + s.length
        l += arg.length if left.size == 1 && arg
        #l < max or left << ''
        left[-1] << if left[-1].empty? then ' ' * 4 else ', ' end << s
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
        yield(indent + l.to_s)
      end

      self
    end 
  end
end