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

class MiniTest::Unit::TestCase
  undef_method :method_name if method_defined?(:method_name)
  
  # MiniTest renames method_name as name.  For backwards compatibility
  # it is added back here.
  def method_name
    name
  end
end