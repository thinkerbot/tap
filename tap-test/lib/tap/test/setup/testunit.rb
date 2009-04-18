# :stopdoc:
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
# :startdoc: