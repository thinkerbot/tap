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

      #def ljustify(str, sep="\n")
      #  regexp = nil
      #  str.split(/\r?\n/).collect do |line|
      #    if regexp == nil 
      #     next if line.strip.empty?
      #      line =~ /^(\s*)/
      #      regexp = Regexp.new("^\\s{#{$1.length}}(.*)")
      #    end
      #    
      #    line = $1 if line =~ regexp
      #    line
      #  end.compact.join(sep)
      #end
      
      def assert_output_equal(a, b, msg=nil)
        if a[1..-1] == b
          assert true
        else
          flunk %Q{
==================== expected output ====================
#{a[1..-1].gsub(/\t/, "\\t").gsub(/\r\n/, "\\r\\n\n").gsub(/\n/, "\\n\n")}
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
        
            test.commands.each do |cmd, msg, expected, block|
              start = Time.now
              result = capture_sh(cmd)
              elapsed = Time.now - start

              if expected
                assert_output_equal(expected, result)
              end
              
              if block
                block.call(result)
              end
              
              if env('stepwise') || (expected == nil && block == nil)
                print %Q{
------------------------------------ (#{method_name})
%s
> %s
%s
Time Elapsed: %.3fs} % [msg, cmd, result, elapsed]

                if env('stepwise')
                  print "\nContinue? (y/n): "
                  break if gets.strip =~ /^no?$/i
                end
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




