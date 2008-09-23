require 'test/unit'
$:.unshift File.expand_path("#{File.dirname(__FILE__)}/..")
require 'tap/test/extensions'

module Test # :nodoc:
  module Unit # :nodoc:
    
    # Methods extending TestCase. For more information see:
    # - Tap::Test::SubsetTest
    # - Tap::Test::FileTest
    # - Tap::Test::TapTest
    #   
    #--
    #See the TestTutorial for more information.
    class TestCase
      extend Tap::Test::Extensions
      
      class << self
        alias tap_original_test_case_inherited inherited
        
        def inherited(child)
          super
          tap_original_test_case_inherited(child)
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
      end
    end
  end
end
