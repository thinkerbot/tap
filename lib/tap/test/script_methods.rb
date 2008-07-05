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
        attr_accessor :command_path
        attr_reader :commands
        
        def initialize
          @command_path = nil
          @commands = []
        end
        
        def check(argstr, msg=nil, expected=nil, &block)
          commands << ["#{command_path}#{argstr}", msg, expected, block]
        end
        
        def check_cmd(cmd, msg=nil, expected=nil, &block)
          commands << [cmd, msg, expected, block]
        end
      end
      
      include Tap::Support::ShellUtils
      
      def assert_output_equal(a, b, cmd, msg)
        a = a[1..-1] if a[0] == ?\n
        if a == b
          assert true
        else
          flunk %Q{
#{msg}
% #{cmd}
==================== expected output ====================
#{a.gsub(/\t/, "\\t").gsub(/\r\n/, "\\r\\n\n").gsub(/\n/, "\\n\n")}
======================== but was ========================
#{b.gsub(/\t/, "\\t").gsub(/\r\n/, "\\r\\n\n").gsub(/\n/, "\\n\n")}
=========================================================
}
        end
      end
      
      def assert_alike(a, b, cmd, msg)
        if b =~ a
          assert true
        else
          flunk %Q{
#{msg}
% #{cmd}
================= expected output like ==================
#{a}
======================== but was ========================
#{b.gsub(/\t/, "\\t").gsub(/\r\n/, "\\r\\n\n").gsub(/\n/, "\\n\n")}
=========================================================
}
        end
      end
      
      def script_test(test_dir=method_dir(:output))
        subset_test("SCRIPT", "s") do
          test = CommandTest.new
          yield(test)
          
          current_dir = Dir.pwd
          current_argv = ARGV.dup
          begin
            ARGV.clear
            make_test_directories
            Dir.chdir(test_dir)
            
            puts "\n# == #{method_name}"
        
            test.commands.each do |cmd, msg, expected, block|
              start = Time.now
              result = capture_sh(cmd)
              elapsed = Time.now - start

              case expected
              when String
                assert_output_equal(expected, result, cmd, msg)
              when Regexp
                assert_alike(expected, result, cmd, msg)
              end
              
              if block
                block.call(result)
              end
              
              if env('stepwise') || (expected == nil && block == nil)
                print %Q{
------------------------------------
%s
> %s
%s
Time Elapsed: %.3fs} % [msg, cmd, result, elapsed]

                if env('stepwise')
                  print "\nContinue? (y/n): "
                  break if gets.strip =~ /^no?$/i
                end
              else            
                puts "%.3fs : %s" % [elapsed, msg]
              end
            end
          ensure
            Dir.chdir(current_dir)
            ARGV.clear
            ARGV.concat(current_argv)
          end
          
        end
      end
      
    end
  end
end




