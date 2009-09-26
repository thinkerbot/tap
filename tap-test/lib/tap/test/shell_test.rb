if RUBY_PLATFORM =~ /mswin32/
  begin
    require 'rubygems'
    require 'win32/open3'
  rescue(LoadError)
    puts %q{
Tap:Test::ShellTest requires the win32-open3 gem on Windows.
Use this command and try again:

  % gem install win32-open3

}
    raise
  end
else
  require 'open3'
end

require 'tap/test/shell_test/class_methods'

module Tap
  module Test
    
    # A module for testing shell scripts.
    #
    #   require 'test/unit'
    #   class ShellTestSample < Test::Unit::TestCase
    #     include Tap::Test::ShellTest
    #
    #     # these are the default sh_test options used 
    #     # in tests like test_sh_command_alias
    #     self.sh_test_options = {
    #       :cmd_pattern => '% inspect_argv',
    #       :cmd => 'ruby -e "puts ARGV.inspect"'
    #     }
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
      
      # Sets the specified ENV variables for the duration of the block.
      # If replace is true, current ENV variables are replaced; otherwise
      # the new env variables are simply added to the existing set.
      def with_env(env={}, replace=false)
        current_env = {}
        ENV.each_pair do |key, value|
          current_env[key] = value
        end
        
        begin
          ENV.clear if replace
          env.each_pair do |key, value|
            ENV[key] = value
          end if env
          
          yield
          
        ensure
          ENV.clear
          current_env.each_pair do |key, value|
            ENV[key] = value
          end
        end
      end
      
      # Executes the command using IO.popen and returns the stdout content.
      #
      # ==== Note
      # On Windows this method requires the {win32-popen3}[http://rubyforge.org/projects/win32utils]
      # utility.  If it is not available, it will have to be installed:
      #
      #   % gem install win32-open3 
      # 
      def sh(cmd)
        Open3.popen3(cmd) do |i,o,s|
          yield(i,o,s) if block_given?
          return o.read
        end
      end
      
      # Peforms a shell test.  Shell tests execute the command and yield the
      # $stdout result to the block for validation.  The command is executed
      # through sh, ie using IO.popen.
      #
      # Options provided to sh_test are merged with the sh_test_options set
      # for the class.
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
      # ==== ENV variables
      #
      # Options may specify a hash of env variables that will be set in the
      # subprocess.
      #
      #   sh_test %Q{
      #   ruby -e "puts ENV['SAMPLE']"
      #   value
      #   }, :env => {'SAMPLE' => 'value'}
      #
      # Note it is better to specify env variables in this way rather than
      # through the command trick 'VAR=value cmd ...', as that syntax does
      # not work on Windows.  As a point of interest, see
      # http://gist.github.com/107363 for a demonstration of ENV
      # variables being inherited by subprocesses.
      # 
      def sh_test(cmd, options={})
        options = sh_test_options.merge(options)
        
        unless quiet? || @shell_test_notification
          @shell_test_notification = true
          puts
          puts method_name 
        end
        
        cmd, expected = cmd.lstrip.split(/\r?\n/, 2)
        original_cmd = cmd
        
        if cmd_pattern = options[:cmd_pattern]
          cmd = cmd.sub(cmd_pattern, options[:cmd].to_s)
        end
        
        start = Time.now
        result = with_env(options[:env], options[:replace_env]) do
          sh(cmd)
        end
        finish = Time.now
        
        elapsed = "%.3f" % [finish-start]
        puts "  (#{elapsed}s) #{verbose? ? cmd : original_cmd}" unless quiet?
        
        assert_equal(expected, result, cmd) if expected
        yield(result) if block_given?
        result
      end
      
      def sh_match(cmd, *regexps)
        options = regexps.last.kind_of?(Hash) ? regexps.pop : {}
        options = sh_test_options.merge(options)
        
        unless quiet? || @shell_test_notification
          @shell_test_notification = true
          puts
          puts method_name 
        end
        
        cmd, expected = cmd.lstrip.split(/\r?\n/, 2)
        original_cmd = cmd
        
        if cmd_pattern = options[:cmd_pattern]
          cmd = cmd.sub(cmd_pattern, options[:cmd].to_s)
        end
        
        start = Time.now
        result = with_env(options[:env], options[:replace_env]) do
          sh(cmd)
        end
        finish = Time.now
        
        elapsed = "%.3f" % [finish-start]
        puts "  (#{elapsed}s) #{verbose? ? cmd : original_cmd}" unless quiet?

        regexps.each do |regexp|
          assert_match regexp, result, cmd
        end
        yield(result) if block_given?
        result
      end
      
      # Returns a hash of the default sh_test options.  See
      # ShellTest::ClassMethods#sh_test_options.
      def sh_test_options
        self.class.sh_test_options
      end
    end
  end
end