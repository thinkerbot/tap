require 'open3'
require 'tap/test/shell_test/class_methods'

module Tap
  module Test
    
    # A module for testing shell scripts.
    #
    #   require 'test/unit'
    #   class ShellTestSample < Test::Unit::TestCase
    #     include Tap::Test::ShellTest
    #
    #     # these are used in test_sh_command_alias 
    #     CMD_PATTERN = '% inspect_env'
    #     CMD = 'ruby -e "puts ENV.inspect"'
    #
    #     def test_echo
    #       assert_equal "goodnight moon", sh("echo goodnight moon").strip
    #     end
    #
    #     def test_echo_using_sh_test
    #       sh_test %q{
    #   echo goodnight moon
    #   goodnight moon
    #   }
    #     end
    #
    #     def test_sh_command_alias
    #       sh_test("% inspect_env") do |output|
    #         assert output !~ /NEW_ENV_VAR/
    #       end
    #
    #       sh_test("NEW_ENV_VAR=blue % inspect_env") do |output|
    #         assert output =~ /NEW_ENV_VAR=blue/
    #       end
    #     end
    #   end
    #
    module ShellTest
      
      def self.included(base) # :nodoc:
        super
        base.extend ShellTest::ClassMethods
      end
      
      # Sets up the ShellTest module.  Be sure to call super if you override
      # setup in an including module.
      def setup
        super
        @shell_test_notification = false
      end
      
      # Returns true if the ENV variable 'VERBOSE' is true.  When verbose,
      # ShellTest prints the expanded commands of sh_test to $stdout.
      def verbose?
        ENV['VERBOSE'] == 'true'
      end
      
      # Returns true if the ENV variable 'QUIET' is true.  When quiet,
      # ShellTest does not print any extra information to $stdout.
      def quiet?
        ENV['QUIET'] == 'true'
      end
      
      # Executes the command using Open3.popen3 and returns the stdout content.
      def sh(cmd)
        Open3.popen3(cmd) do |stdin, stdout, stderr|
          yield(stdin, stdout, stderr) if block_given?
          stdout.read
        end
      end
      
      # Peforms a shell test.  Shell tests execute the command and yield the
      # $stdout result to the block for validation.
      #
      # ==== Command Aliases
      #
      # The options allow specification of a command pattern that gets
      # replaced with a command alias.  Only the first instance of the command
      # pattern is replaced.  In addition, shell tests allow the expected result
      # to be specified inline with the command.  Used together, these allow
      # multiple tests of a complex command to be specified easily:
      #
      #   opts = {
      #     :cmd_pattern => '% argv_inspect',
      #     :cmd => 'ruby -e "puts ARGV.inspect"'
      #   }
      #
      #   sh_test %Q{
      #   % argv_inspect goodnight moon
      #   ["goodnight", "moon"]
      #   }, opts
      #
      #   sh_test %Q{
      #   % argv_inspect hello world
      #   ["hello", "world"]
      #   }, opts
      #
      # Note that the default options are specified by the sh_test_options
      # method, which sets :cmd_pattern and :cmd using the class constants
      # CMD_PATTERN and CMD, if they are defined.
      def sh_test(cmd, options=sh_test_options)
        unless quiet? || @shell_test_notification
          @shell_test_notification = true
          puts
          puts method_name 
        end
        
        cmd, expected = cmd.lstrip.split(/\r?\n/, 2)
        original_cmd = cmd
        
        if cmd_pattern = options[:cmd_pattern]
          cmd = cmd.sub(cmd_pattern, options[:cmd])
        end
        
        start = Time.now
        result = sh(cmd)
        finish = Time.now
        
        elapsed = "%.3f" % [finish-start]
        puts "  (#{elapsed}s) #{verbose? ? cmd : original_cmd}" unless quiet?
        
        assert_equal(expected, result, cmd) if expected
        yield(result) if block_given?
        result
      end
      
      # Returns a hash of the default sh_test options.  See
      # ShellTest::ClassMethods#sh_test_options.
      def sh_test_options
        @sh_test_options ||= self.class.sh_test_options
      end
    end
  end
end