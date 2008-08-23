module Tap
  module Spec
    module Adapter
      def method_name
        self.description.strip.gsub(/\s+/, "_")
      end
      
      # A method serving as the dumping ground for 'should ==' statements
      # that otherwise cause a 'useless use of <method> in void context' 
      # warning. Useful if you're running tests with -w.
      #
      #   check 1.should == 1
      #
      # Check will validate that the line calling check contains a 
      # should/should_not statement; the check fails if it does not.
      def check(return_value)
        return false unless SCRIPT_LINES__
        
        caller[0] =~ /^(([A-z]:)?[^:]+):(\d+)/

        check_file = SCRIPT_LINES__[$1]
        violated("could not validate check: #{$1} (#{$3})") unless check_file 

        # note the line number in caller 
        # starts at 1, not 0
        line = check_file[$3.to_i - 1]
        case line
        when /\.should(_not)?[^\w]/ 
          true # pass
        when /^\s+check/
          violated("check used without should/should_not statement: #{line} (#{caller[0]})")
        else
          violated("multiline check statements are not allowed: #{caller[0]}")
        end
      end
      
      # Maps flunk to violated.
      def flunk(msg)
        violated(msg)
      end
      
      # Maps assert_equal to actual.should == expected.
      def assert_equal(expected, actual, msg=nil)
        check actual.should == expected
      end
    end
  end
end