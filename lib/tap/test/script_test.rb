require 'tap/test/assertions'
require 'tap/test/script_tester'
require 'tap/test/subset_test'

module Tap
  module Test
    module ScriptTest
      
      def self.included(base)
        super
        base.send(:include, Tap::Test::SubsetTest)
        base.send(:include, Tap::Test::Assertions) 
      end
      
      def default_command_path
        nil
      end
      
      def script_test(test_dir=method_root.root)
        subset_test("SCRIPT", "s") do
          Tap::Root.chdir(test_dir, true) do  
            Utils.with_argv do
              puts "\n# == #{method_name}"

              cmd = ScriptTester.new(default_command_path, env('stepwise')) do |expected, result, msg|
                case expected
                when String
                  assert_output_equal(expected, result, msg)
                when Regexp
                  assert_alike(expected, result, msg)
                end
              end
              
              yield(cmd)
            end
          end
        end
      end
      
    end
  end
end




