require 'test/unit'
$:.unshift File.expand_path("#{File.dirname(__FILE__)}/..")

module Test # :nodoc:
  module Unit # :nodoc:
    
    # Methods extending TestCase. For more information see:
    # - Tap::Test::SubsetMethods
    # - Tap::Test::FileMethods
    # - Tap::Test::TapMethods
    #   
    #--
    #See the TestTutorial for more information.
    class TestCase
      class << self
        
        def inherited(child)
          child.instance_variable_set(:@skip_messages, [])
          child.instance_variable_set(:@run_test_suite, true)
        end
        
        # Indicates when the test suite should be run or skipped.
        attr_accessor :run_test_suite
        
        # An array of messages printed when a test is skipped
        # by setting run_test_suite to false.
        attr_reader :skip_messages

        # Causes a test suite to be skipped.  If a message is given, it will
        # print and notify the user the test suite has been skipped.
        def skip_test(msg=nil)
          self.run_test_suite = false

          # experimental -- perhaps use this so that a test can be skipped
          # for multiple reasons?
          skip_messages << msg
        end

        alias :original_suite :suite

        # Modifies the default suite method to skip the suit unless
        # run_test_suite is true.  If the test is skipped, the skip_messages 
        # will be printed along with the default 'Skipping <Test>' message.
        def suite # :nodoc:
          if run_test_suite
            original_suite
          else
            skip_message = skip_messages.compact.join(', ')
            puts "Skipping #{name}#{skip_message.empty? ? '' : ': ' + skip_message}"
            
            # return an empty test suite of the appropriate name
            Test::Unit::TestSuite.new(name)
          end
        end
        
        # Causes a TestCase to act as a file test, by including FileMethods and
        # instantiating test_root (a Tap::Root used to determine a variety of
        # test filepaths).  The root and directories used by test_root may be 
        # specified as options.  
        #
        # Note: by default acts_as_file_test determines a root directory 
        # <em>based on the calling file</em>.  Be sure to specify the root 
        # directory manually if you call acts_as_file_test from a file that 
        # isn't the test file.
        def acts_as_file_test(options={})
          include Tap::Test::FileMethods
          
          options = {
            :root => test_root_dir,
            :directories => {
              :input => 'input',
              :output => 'output',
              :expected => 'expected'}
          }.merge(options)
          
          self.test_root = Tap::Root.new(options[:root], options[:directories])
        end

        # Causes a unit test to act as a tap test -- resulting in the following:
        # - setup using acts_as_file_test
        # - inclusion of Tap::Test::SubsetMethods
        # - inclusion of Tap::Test::InstanceMethods 
        #
        # Note: by default acts_as_tap_test determines a root directory 
        # <em>based on the calling file</em>.  Be sure to specify the root 
        # directory manually if you call acts_as_file_test from a file that 
        # isn't the test file.
        def acts_as_tap_test(options={})
          include Tap::Test::SubsetMethods
          include Tap::Test::FileMethods
          include Tap::Test::TapMethods
          
          acts_as_file_test({:root => test_root_dir}.merge(options))
        end

        def acts_as_script_test(options={})
          include Tap::Test::FileMethods
          include Tap::Test::ScriptMethods
          
          acts_as_file_test({:root => test_root_dir}.merge(options))
        end
        
        private
        
        # Infers the test root directory from the calling file.
        #   'some_class.rb' => 'some_class'
        #   'some_class_test.rb' => 'some_class'
        def test_root_dir # :nodoc:
          # caller[1] is considered the calling file (which should be the test case)
          # note that the output of calller.first is like:
          #   ./path/to/file.rb:10
          #   ./path/to/file.rb:10:in 'method'
          calling_file = caller[1].gsub(/:\d+(:in .*)?$/, "")
          calling_file.chomp(File.extname(calling_file)).chomp("_test") 
        end
         
      end
    end
  end
end

module Tap
  
  # Modules facilitating testing.  TapMethods are specific to
  # Tap, but SubsetMethods and FileMethods are more general in 
  # their utility.
  module Test
    autoload(:SubsetMethods, 'tap/test/subset_methods')
    autoload(:FileMethods, 'tap/test/file_methods')
    autoload(:TapMethods, 'tap/test/tap_methods')
    autoload(:Utils, 'tap/test/utils')
  end
end




