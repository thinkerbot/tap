module Tap
  module Spec
    module Adapter
      def setup
      end
      
      def teardown
      end
      
      def method_name
        self.description.strip.gsub(/\s+/, "_")
      end
      
      # Maps flunk to violated.
      def flunk(msg)
        violated(msg)
      end
      
      # Maps assert_equal to actual.should.equal expected.
      def assert_equal(expected, actual, msg=nil)
        actual.should == expected
      end
    end
  end
end