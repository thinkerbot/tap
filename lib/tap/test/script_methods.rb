require 'test/unit'
require 'tap/test/file_methods'
require 'tap/test/subset_methods'
#require 'tap/support/shell_utils'

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
      class CommandTest
        include Tap::Support::ShellUtils
         
        attr_accessor :command_path
        attr_reader :commands
        
        def initialize(command_path=nil)
          @command_path = command_path
          @commands = []
        end
        
        def check(argstr, msg=nil, expected=nil, &validation)
          commands << ["#{command_path}#{argstr}", msg, expected, validation]
        end
        
        def check_cmd(cmd, msg=nil, expected=nil, &validation)
          commands << [cmd, msg, expected, validation]
        end
        
        def run(stepwise=false)
          commands.each do |cmd, msg, expected, validation|
            start = Time.now
            result = capture_sh(cmd) {|ok, status, tempfile_path| }
            elapsed = Time.now - start
            
            yield(expected, result, %Q{#{msg}\n% #{cmd}}) if expected
            validation.call(result) if validation

            if stepwise || (expected == nil && validation == nil)
              print %Q{
------------------------------------
%s
> %s
%s
Time Elapsed: %.3fs} % [msg, cmd, result, elapsed]

              if stepwise
                print "\nContinue? (y/n): "
                break if gets.strip =~ /^no?$/i
              end
            else            
              puts "%.3fs : %s" % [elapsed, msg]
            end
          end
        end
      end
      
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
          test = CommandTest.new(default_command_path)
          yield(test)
          
          Tap::Root.indir(test_dir, true) do
            with_argv do
              puts "\n# == #{method_name}"

              test.run(env('stepwise')) do |expected, result, msg|
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




