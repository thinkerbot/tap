module Tap
  module Test
    module ShellTest
      # Class methods extending tests which include ShellTest.
      module ClassMethods
      
        # Sets the default sh_test_options
        attr_writer :sh_test_options
        
        # Returns a hash of the default sh_test options.
        def sh_test_options
          @sh_test_options ||= {}
        end

        private

        # helper to retrieve class constants
        def class_const(const_name) # :nodoc:
          const_defined?(const_name) ? const_get(const_name) : nil
        end
      end
    end
  end
end