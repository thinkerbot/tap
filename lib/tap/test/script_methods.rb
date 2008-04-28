require 'test/unit'
require 'tap/test/file_methods'
require 'tap/test/subset_methods'
#require 'tap/support/shell_utils'

module Test # :nodoc:
  module Unit # :nodoc:
    class TestCase
      class << self

        def acts_as_script_test(options={})
          options = {:root => file_test_root}.merge(options.symbolize_keys)
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
        
        def check(argstr, msg=nil, &block)
          commands << ["#{command_path}#{argstr}", msg, block]
        end
        
        def check_cmd(cmd, msg=nil, &block)
          commands << [cmd, msg, block]
        end
      end
      
      #include Tap::Support::ShellUtils
      
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
      
      @@run_all = false
      
      def script_test(test_dir=method_dir(:output), &block)
        subset_test("SCRIPT", "s") do
          test = CommandTest.new
          yield(test)
          
          current_dir = Dir.pwd
          current_argv = ARGV.dup
          begin
            ARGV.clear
            make_test_directories
            Dir.chdir(test_dir)
        
            test.commands.each do |cmd, msg, block|
              puts "------------------------------------"
              puts
              puts msg
              puts "> #{cmd}"
  
              unless @@run_all
                print "Run? (y/n/a): "
                case gets.strip 
                when /^no?$/i then break 
                when /^a(ll)?$/i 
                  @@run_all = true
                end 
              end
              
              start = Time.now
              system(cmd)
              elapsed = Time.now - start
              print "Time Elapsed: %.3fs " % [elapsed]

              block.call unless block == nil
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




