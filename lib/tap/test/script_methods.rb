require 'test/unit'
require 'tap/test/file_methods'
require 'tap/test/subset_methods'
require 'tap/test/script_methods/script_test'

module Test # :nodoc:
  module Unit # :nodoc:
    class TestCase
      class << self

        def acts_as_script_test(options={})
          options = options.inject({:root => file_test_root}) do |hash, (key, value)|
            hash[key.to_sym || key] = value
            hash
          end
          acts_as_file_test(options)
          include Tap::Test::SubsetMethods
          include Tap::Test::ScriptMethods
        end
        
      end
    end
  end
end

module Tap
  module Test
    module ScriptMethods
            
      def assert_output_equal(a, b, msg)
        a = a[1..-1] if a[0] == ?\n
        if a == b
          assert true
        else
          flunk %Q{
#{msg}
==================== expected output ====================
#{a.gsub(/\t/, "\\t").gsub(/\r\n/, "\\r\\n\n").gsub(/\n/, "\\n\n")}
======================== but was ========================
#{b.gsub(/\t/, "\\t").gsub(/\r\n/, "\\r\\n\n").gsub(/\n/, "\\n\n")}
=========================================================
}
        end
      end
      
      def assert_alike(a, b, msg)
        if b =~ a
          assert true
        else
          flunk %Q{
#{msg}
================= expected output like ==================
#{a}
======================== but was ========================
#{b.gsub(/\t/, "\\t").gsub(/\r\n/, "\\r\\n\n").gsub(/\n/, "\\n\n")}
=========================================================
}
        end
      end
      
      def with_argv(argv=[])
        current_argv = ARGV.dup
        begin
          ARGV.clear
          ARGV.concat(argv)
          
          yield
          
        ensure
          ARGV.clear
          ARGV.concat(current_argv)
        end
      end
      
      def default_command_path
        nil
      end
      
      def script_test(test_dir=method_root)
        subset_test("SCRIPT", "s") do
          cmd = ScriptTest.new(default_command_path)
          yield(cmd)
          
          Tap::Root.indir(test_dir, true) do
            with_argv do
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




