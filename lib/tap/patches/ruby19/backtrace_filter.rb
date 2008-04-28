module Test
  module Unit
    module Util # :nodoc:
      module BacktraceFilter # :nodoc:
        
        if method_defined?(:filter_backtrace)
          alias :tap_original_filter_backtrace :filter_backtrace
        end
        
        # This is a slightly-modified version of the default BacktraceFilter
        # provided in the Ruby 1.9 distribution.  It solves the issue documented
        # below, and hopefully will not be necessary when Ruby 1.9 is stable.
        #
        def filter_backtrace(backtrace, prefix=nil)
          return ["No backtrace"] unless(backtrace)
          split_p = if(prefix)
            prefix.split(TESTUNIT_FILE_SEPARATORS)
          else
            TESTUNIT_PREFIX
          end
          match = proc do |e|
            split_e = e.split(TESTUNIT_FILE_SEPARATORS)[0, split_p.size]
            next false unless(split_e[0..-2] == split_p[0..-2])
            split_e[-1].sub(TESTUNIT_RB_FILE, '') == split_p[-1]
          end
          
          # The Ruby 1.9 issue is that sometimes backtrace is a String
          # and String is no longer Enumerable (hence it doesn't respond
          # respond to detect).  Arrayify to solve.
          backtrace = [backtrace] unless backtrace.kind_of?(Array)
          
          return backtrace unless(backtrace.detect(&match))
          found_prefix = false
          new_backtrace = backtrace.reverse.reject do |e|
            if(match[e])
              found_prefix = true
              true
            elsif(found_prefix)
              false
            else
              true
            end
          end.reverse
          new_backtrace = (new_backtrace.empty? ? backtrace : new_backtrace)
          new_backtrace = new_backtrace.reject(&match)
          new_backtrace.empty? ? backtrace : new_backtrace
        end
      end
    end
  end
end