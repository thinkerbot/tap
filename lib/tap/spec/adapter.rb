module Tap
  module Spec
    module Adapter
      def method_name
        self.description.strip.gsub(/\s+/, "_")
      end
      
      # A method that does nothing but can serve as the dumping ground for statements
      # that otherwise cause a 'useless use of <method> in void context' warning.
      # Useful if you're running tests with -w.
      #
      #   check 1.should == 1
      #
      def check(return_value)
        caller[0] =~ /^(([A-z]:)?[^:]+):(\d+)/
        
        check_file = SCRIPT_LINES__[$1]
        violated("could not validate check: #{$1} (#{$3})") unless check_file 
        
        line = check_file[$3.to_i - 1]
        violated("check used without should/should_not statement: #{line} (#{caller[0]})") unless line =~ /\.should(_not)?[^\w]/
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