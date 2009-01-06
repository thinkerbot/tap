require 'benchmark'
require 'tap/test/subset_test_class'

module Tap
  module Test
    
    # SubsetTest provides methods to conditionally run tests, or to skip a 
    # test suite entirely.
    # 
    #   require 'tap/test'
    #
    #   class Test::Unit::TestCase
    #     # only true if running on windows
    #     condition(:windows) { match_platform?('mswin') }
    # 
    #     # only true if running on anything but windows
    #     condition(:non_windows) { match_platform?('non_mswin') }
    #   end
    # 
    #   class WindowsOnlyTest < Test::Unit::TestCase
    #     skip_test unless satisfied?(:windows)
    #   end
    # 
    # Here the WindowsOnlyTest will only run on a Windows platform. Conditions
    # like these may be targeted at specific tests when only some tests need 
    # to be skipped.
    # 
    #   class RunOnlyAFewTest < Test::Unit::TestCase
    #     include SubsetTest
    # 
    #     def test_runs_all_the_time
    #       assert true
    #     end
    # 
    #     def test_runs_only_if_non_windows_condition_is_true
    #       condition_test(:non_windows) { assert true }
    #       end
    #     end
    # 
    #     def test_runs_only_when_ENV_variable_EXTENDED_is_true
    #       extended_test { assert true }
    #     end
    # 
    #     def test_runs_only_when_ENV_variable_BENCHMARK_is_true
    #       benchmark_test do |x|
    #         x.report("init speed") { 10000.times { Object.new } }
    #       end
    #     end
    #
    #     def test_runs_only_when_ENV_variable_CUSTOM_is_true
    #       subset_test('CUSTOM') { assert true }
    #     end
    #   end
    # 
    # In the example, the ENV variables EXTENDED, BENCHMARK, and CUSTOM act as
    # flags to run specific tests.  If you're running your test using Rake, ENV
    # variables can be set from the command line like so:
    # 
    #   % rake test EXTENDED=true
    #   % rake test BENCHMARK=true
    # 
    # Since tap and rap can run rake tasks as well, these are equivalent:
    #
    #   % tap run test EXTENDED=true
    #   % rap test BENCHMARK=true
    #
    # In so far as SubsetTest is concerned, the environment variables are 
    # case-insensitive.  As in the example, additional ENV-based tests can be 
    # defined using the subset_test method. To run all tests that get switched 
    # using an ENV variable, set ALL=true.  
    #
    #   # also runs benchmark tests
    #   % rap test BenchMark=true
    #
    #   # runs all tests
    #   % rap test all=true
    #
    # See {Test::Unit::TestCase}[link:classes/Test/Unit/TestCase.html] and
    # SubsetTestClass for more information.
    module SubsetTest
      include Tap::Test::EnvVars
      
      def self.included(base)
        super
        base.extend SubsetTestClass
      end
      
      # Returns true if the specified conditions are satisfied.
      def satisfied?(*condition_names)
        self.class.satisfied?(*condition_names)
      end
      
      # Returns true if the subset type (ex 'BENCHMARK') or 'ALL' is
      # specified in ENV.
      def run_subset?(type)
        self.class.run_subset?(type)
      end

      # Returns true if the input string matches the regexp specified in 
      # env_var(type). Returns the default value if 'ALL' is specified in
      # ENV or type is not specified in ENV.  
      def match_regexp?(type, str, default=true)
        return true if env_true?("ALL")
        return default unless env(type)
    
        str =~ Regexp.new(env(type)) ? true : false
      end

      # Platform-specific test.  Useful for specifying test that should only 
      # be run on a subset of platforms.  Prints ' ' if the test is not run.
      #
      #   def test_only_on_windows
      #     platform_test('mswin') { ... }
      #   end
      #
      # See SubsetTestClass#match_platform? for matching details.
      def platform_test(*platforms)
        if self.class.match_platform?(*platforms)
          yield
        else
          print ' '
        end
      end
      
      # Conditonal test.  Only runs if the specified conditions are satisfied.
      # If no conditons are explicitly set, condition_test only runs if ALL 
      # conditions for the test are satisfied.
      # 
      #   condition(:is_true) { true }
      #   condition(:is_false) { false }
      #
      #   def test_only_if_true_is_satisfied
      #     condition_test(:is_true) { # runs }
      #   end
      #
      #   def test_only_if_all_conditions_are_satisfied
      #     condition_test {  # does not run }
      #   end
      #
      # See SubsetTestClass#condition for more details.
      def condition_test(*condition_names)
        if self.class.unsatisfied_conditions(*condition_names).empty?
          yield
        else
          print ' '
        end
      end
      
      # Defines a subset test.  The provided block will only run if:
      # - the subset type is specified in ENV
      # - the subset 'ALL' is specified in ENV
      # - the test method name matches the regexp provided in the 
      #   <TYPE>_TEST ENV variable
      #  
      # Otherwise the block will be skipped and +skip+ will be printed in the
      # test output.  By default skip is the first letter of +type+.
      #
      # For example, with these methods:
      #
      #   def test_one
      #     subset_test('CUSTOM') { assert true }
      #   end
      #
      #   def test_two
      #     subset_test('CUSTOM') { assert true }
      #   end
      #
      #   Condition                    Tests that get run
      #   ENV['ALL']=true              test_one, test_two
      #   ENV['CUSTOM']=true           test_one, test_two
      #   ENV['CUSTOM_TEST']=test_     test_one, test_two
      #   ENV['CUSTOM_TEST']=test_one  test_one
      #   ENV['CUSTOM']=nil            no tests get run
      # 
      # If you're running your tests with rake (or rap), ENV variables may be
      # set from the command line.
      #
      #   # all tests
      #   % rap test all=true
      #
      #   # custom subset tests
      #   % rap test custom=true
      #
      #   # just test_one (it is the only test
      #   # matching the '.est_on.' pattern)
      #   % rap test custom_test=.est_on.
      #
      def subset_test(type, skip=type[0..0].downcase)
        type = type.upcase
        type_test = "#{type}_TEST"
        if run_subset?(type) || env(type_test)
          if match_regexp?(type_test, name.to_s)
            yield
          else
            print skip
          end
        else
          print skip
        end
      end
  
      # Declares a subset_test for the ENV variable 'EXTENDED'.
      # Prints 'x' if the test is not run.
      #
      #   def test_some_long_process
      #     extended_test { ... }
      #   end
      def extended_test(&block) 
        subset_test("EXTENDED", "x", &block)
      end
  
      # Declares a subset_test for the ENV variable 'BENCHMARK'. If run, 
      # benchmark_test sets up benchmarking using the Benchmark.bm method 
      # using the input length and block.  Prints 'b' if the test is not run.
      #
      #   include Benchmark
      #   def test_speed
      #     benchmark_test(10) {|x| ... }
      #   end
      def benchmark_test(length=10, &block) 
        subset_test("BENCHMARK") do
          puts
          puts name
          Benchmark.bm(length, &block)
        end
      end

      # Declares a subset_test for the ENV variable 'PROMPT'. When run, prompts
      # the user for each input specified in array.  Inputs will then be passed
      # as a hash to the block.  Prints 'p' unless run.
      # 
      #   def test_requiring_inputs
      #     prompt_test(:a, :b, :c) {|a, b, c| ... }
      #   end
      #
      # If run, the command line prompt will be like the following:
      #
      #   test_requiring_inputs: Enter values or 'skip'
      #   a: avalue
      #   b: bvalue      
      #   c: cvalue
      #
      # The block recieves ['avalue', 'bvalue', 'cvalue'].  
      def prompt_test(*keys, &block)
        subset_test("PROMPT", "p") do
          puts "\n#{name} -- Enter values or 'skip'."
  
          values = keys.collect do |key|
            print "#{key}: "
            value = gets.strip
            flunk "skipped test" if value =~ /skip/i
            value
          end
        
          yield(*values)
        end
      end
    end
  end
end