module Tap
  module Test
    
    # Class methods extending tests which include ShellTest.
    module ShellTest
      module ClassMethods
      
        # Sets the default sh_test_options
        attr_writer :sh_test_options
        
        # Returns a hash of the default sh_test options, which are specified
        # using the class constants CMD_PATTERN and CMD, if they are set.
        #
        #   class ShellTestOptionsExample
        #     include ShellTest
        #
        #     CMD_PATTERN = '% sample'
        #     CMD = 'command'
        #   end
        #
        #   options = ShellTestOptionsExample.sh_test_options
        #   options[:cmd_pattern]      # => '% sample'
        #   options[:cmd]              # => 'command'
        #
        def sh_test_options
          @sh_test_options ||= {
            :cmd_pattern => class_const(:CMD_PATTERN),
            :cmd => class_const(:CMD),
            :env => {}
          }
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