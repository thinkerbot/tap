module Tap
  module Spec
    module Adapter
      def method_name
        self.description.gsub(" ", "_")
      end
      
      # A method that does nothing but can serve as the dumping ground for statements
      # that otherwise cause a 'useless use of <method> in void context' warning.
      # Useful if you're running tests with -w.
      #
      #   check 1.should == 1
      #
      def check(*args)
      end
      
    end
  end
end