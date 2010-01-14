module Tap
  module Test
    module ShellTest
      # Class methods extending tests which include ShellTest.
      module ClassMethods
      
        # Sets the default sh_test_options
        attr_writer :sh_test_options
        
        # Returns a hash of the default sh_test options.
        def sh_test_options
          @sh_test_options ||= {
            :cmd_pattern => '% ',
            :cmd => '2>&1 ',
            :indents => true
          }
        end
      end
    end
  end
end