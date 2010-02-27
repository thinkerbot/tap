module Tap
  module Utils
    module_function
    
    def warn_ignored_args(args)
      if args && !args.empty?
        warn "ignoring args: #{args.inspect}"
      end
    end
    
    def shellsplit(line, comment="#")
      words = []
      field = ''
      line.scan(/\G\s*(?>([^\s\\\'\"]+)|'([^\']*)'|"((?:[^\"\\]|\\.)*)"|(\\.?)|(\S))(\s|\z)?/m) do
        |word, sq, dq, esc, garbage, sep|
        raise ArgumentError, "Unmatched double quote: #{line.inspect}" if garbage
        break if word == comment
        field << (word || sq || (dq || esc).gsub(/\\(?=.)/, ''))
        if sep
          words << field
          field = ''
        end
      end
      words
    end
    
    def each_signal(io)
      offset = -1 * ($/.length + 1)
      
      carryover = nil
      io.each_line do |line|
        if line[offset] == ?\\
          carryover ||= []
          carryover << line[0, line.length + offset]
          carryover << $/
          next
        end
        
        if carryover
          carryover << line
          line = carryover.join
          carryover = nil
        end
        
        sig, *args = shellsplit(line)
        yield(sig, args) if sig
      end
    end
  end
end