require 'tap/test/subset_methods'
require 'tap/test/script_methods/script_test'

module Tap
  module Test
    module ScriptMethods
      
      def self.included(base)
        super
        base.send(:include, Tap::Test::SubsetMethods)  
      end
      
      def assert_output_equal(a, b, msg=nil)
        a = a[1..-1] if a[0] == ?\n
        if a == b
          assert true
        else
          flunk %Q{
#{msg}
==================== expected output ====================
#{Utils.whitespace_escape(a)}
======================== but was ========================
#{Utils.whitespace_escape(b)}
=========================================================
}
        end
      end
      
      def assert_alike(a, b, msg=nil)
        if b =~ a
          assert true
        else
          flunk %Q{
#{msg}
================= expected output like ==================
#{a}
======================== but was ========================
#{Utils.whitespace_escape(b)}
=========================================================
}
        end
      end
      
      def default_command_path
        nil
      end
      
      def script_test(test_dir=method_root.root)
        subset_test("SCRIPT", "s") do
          cmd = ScriptTest.new(default_command_path)
          yield(cmd)
          
          Tap::Root.chdir(test_dir, true) do
            Utils.with_argv do
              puts "\n# == #{method_name}"

              cmd.run(env('stepwise')) do |expected, result, msg|
                case expected
                when String
                  assert_output_equal(expected, result, msg)
                when Regexp
                  assert_alike(expected, result, msg)
                end
              end
            end
          end
        end
      end
      
    end
  end
end




