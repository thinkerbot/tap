require 'tap/test/shell_test/class_methods'
require 'tap/test/shell_test/regexp_escape'

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
        @notify_method_name = true
      end
      
      # Returns true if the ENV variable 'VERBOSE' is true.  When verbose,
      # ShellTest prints the expanded commands of sh_test to $stdout.
      def verbose?
        verbose = ENV['VERBOSE']
        verbose && verbose =~ /^true$/i ? true : false
      end
      
      # Returns true if the ENV variable 'QUIET' is true.  When quiet,
      # ShellTest does not print any extra information to $stdout.
      #
      # If 'VERBOSE' and 'QUIET' are both set, verbose wins.
      def quiet?
        return false if verbose?
        
        quiet = ENV['QUIET']
        quiet && quiet =~ /^true$/i ? true : false
      end
      
      # Sets the specified ENV variables and returns the *current* env.
      # If replace is true, current ENV variables are replaced; otherwise
      # the new env variables are simply added to the existing set.
      def set_env(env={}, replace=false)
        current_env = {}
        ENV.each_pair do |key, value|
          current_env[key] = value
        end
        
        ENV.clear if replace
        
        env.each_pair do |key, value|
          ENV[key] = value
        end if env
        
        current_env
      end
      
      # Sets the specified ENV variables for the duration of the block.
      # If replace is true, current ENV variables are replaced; otherwise
      # the new env variables are simply added to the existing set.
      #
      # Returns the block return.
      def with_env(env={}, replace=false)
        current_env = nil
        begin
          current_env = set_env(env, replace)
          yield
        ensure
          if current_env
            set_env(current_env, true)
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
      def sh(cmd, options={})
        if @notify_method_name && !quiet?
          @notify_method_name = false
          puts
          puts method_name 
        end
        
        original_cmd = cmd
        if cmd_pattern = options[:cmd_pattern]
          cmd = cmd.sub(cmd_pattern, options[:cmd].to_s)
        end
        
        start = Time.now
        result = with_env(options[:env], options[:replace_env]) do
          IO.popen(cmd) do |io|
            yield(io) if block_given?
            io.read
          end
        end
        
        finish = Time.now
        elapsed = "%.3f" % [finish-start]
        puts "  (#{elapsed}s) #{verbose? ? cmd : original_cmd}" unless quiet?
        result
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
      # ==== Indents
      #
      # To improve the readability of tests, sh_test will lstrip each line in the
      # expected output to the same degree as the command line.  So for instance
      # these all pass:
      #
      #   sh_test %Q{
      #   % argv_inspect hello world
      #   ["hello", "world"]
      #   }, opts
      #
      #   sh_test %Q{
      #       % argv_inspect hello world
      #       ["hello", "world"]
      #   }, opts
      #
      #       sh_test %Q{
      #       % argv_inspect hello world
      #       ["hello", "world"]
      #       }, opts
      #
      # Turn off indent stripping by specifying :indent => false.
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
        
        if cmd =~ /\A\s*?\n?(\s*)(.*?\n)(.*)\z/m
          indent, cmd, expected = $1, $2, $3
          cmd.strip!
          
          if indent.length > 0 && options[:indents]
            expected.gsub!(/^\s{0,#{indent.length}}/, '')
          end
        end
        
        result = sh(cmd, options)
        
        assert_equal(expected, result, cmd) if expected
        yield(result) if block_given?
        result
      end
      
      def sh_match(cmd, *regexps)
        
        options = regexps.last.kind_of?(Hash) ? regexps.pop : {}
        options = sh_test_options.merge(options)
        result = sh(cmd, options)

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
      
      def assert_output_equal(a, b, msg=nil)
        a = a[1..-1] if a[0] == ?\n
        if a == b
          assert true
        else
          flunk %Q{
#{msg}
==================== expected output ====================
#{whitespace_escape(a)}
======================== but was ========================
#{whitespace_escape(b)}
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
#{whitespace_escape(a)}
======================== but was ========================
#{whitespace_escape(b)}
=========================================================
}
        end
      end
      
      private
      
      def whitespace_escape(str)
        str.to_s.gsub(/\s/) do |match|
          case match
          when "\n" then "\\n\n"
          when "\t" then "\\t"
          when "\r" then "\\r"
          when "\f" then "\\f"
          else match
          end
        end
      end
    end
  end
end