require 'test/unit'
require 'tap/test'

if Object.const_defined?(:MiniTest)
  
  ################################
  # MiniTest shims (ruby 1.9)
  ################################
  
  # Tap-Test adds a class skip_test method to TestCase to allow a full class
  # to be skipped (for instance due to a failed Tap::Test::SubsetTest
  # condition).  The method is not required by any Tap-Test module.
  class Test::Unit::TestCase
    class << self
      # Causes a test suite to be skipped.  If a message is given, it will
      # print and notify the user the test suite has been skipped.
      def skip_test(msg=nil)
        @@test_suites.delete(self)
        puts "Skipping #{self}#{msg.empty? ? '' : ': ' + msg}"
      end
    end
  end
  
  # MiniTest renames method_name as name.  For backwards compatibility
  # (and for Tap::Test::FileTest) it must be added back.
  class MiniTest::Unit::TestCase
    def method_name
      name
    end
  end

  MiniTest::Unit::TestCase.extend Tap::Test

else
  
  ################################
  # Test::Unit shims (< ruby 1.9)
  ################################
  # :stopdoc:
  # Implementing skip_test in the original Test::Unit is considerably more
  # tricky than in the Mini::Test Test::Unit.
  class Test::Unit::TestCase
    class << self
      alias tap_original_test_case_inherited inherited
    
      def inherited(child)
        super
        tap_original_test_case_inherited(child)
        child.instance_variable_set(:@skip_messages, [])
        child.instance_variable_set(:@run_test_suite, true)
      end
    
      # Causes a test suite to be skipped.  If a message is given, it will
      # print and notify the user the test suite has been skipped.
      def skip_test(msg=nil)
        @run_test_suite = false
        @skip_messages << msg
      end
    
      alias :original_suite :suite

      # Modifies the default suite method to skip the suit unless
      # run_test_suite is true.  If the test is skipped, the skip_messages 
      # will be printed along with the default 'Skipping <Test>' message.
      def suite # :nodoc:
        if @run_test_suite
          original_suite
        else
          skip_message = @skip_messages.compact.join(', ')
          puts "Skipping #{name}#{skip_message.empty? ? '' : ': ' + skip_message}"

          # return an empty test suite of the appropriate name
          Test::Unit::TestSuite.new(name)
        end
      end
    end
  end
  
  Test::Unit::TestCase.extend Tap::Test
  # :startdoc:
end


