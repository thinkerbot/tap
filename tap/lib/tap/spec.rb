$:.unshift File.expand_path("#{File.dirname(__FILE__)}/..")
require 'tap/test/extensions'

require 'rubygems'
require 'minitest/spec'

# :stopdoc:
class MiniTest::Unit::TestCase
  extend Tap::Test::Extensions
  
  class << self
    # Causes a test suite to be skipped.  If a message is given, it will
    # print and notify the user the test suite has been skipped.
    def skip_test(msg=nil)
      @@test_suites.delete(self)
      puts "Skipping #{self}#{msg.empty? ? '' : ': ' + msg}"
    end
    
    private
    
    # Infers the test root directory from the calling file.
    #   'some_class.rb' => 'some_class'
    #   'some_class_test.rb' => 'some_class'
    def test_root_dir # :nodoc:
      # caller[1] is considered the calling file (which should be the test case)
      # note that caller entries are like this:
      #   ./path/to/file.rb:10
      #   ./path/to/file.rb:10:in 'method'
      
      calling_file = caller[1].gsub(/:\d+(:in .*)?$/, "")
      calling_file.chomp(File.extname(calling_file)).chomp("_spec") 
    end
  end
  
  def method_name
    @method_name ||= name.gsub(/\s/, "_").gsub(/^test_/, "")
  end
end

MiniTest::Unit.autorun
# :startdoc: