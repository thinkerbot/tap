require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb') 
require 'tap/tasks/doc'

class DocTest < Test::Unit::TestCase
  acts_as_tap_test 
  
  def test_doc
    task = Tap::Tasks::Doc.new :message => "goodnight"
    
    # a simple test
    assert_equal({:message  => 'goodnight'}, task.config)
    assert_equal "goodnight moon", task.process("moon")
  end
end