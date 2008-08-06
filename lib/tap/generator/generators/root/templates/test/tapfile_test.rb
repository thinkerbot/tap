require File.dirname(__FILE__) + '/tap_test_helper.rb'
require File.dirname(__FILE__) + '/../tapfile.rb'

class TapfileTest < Test::Unit::TestCase
  acts_as_tap_test
  
  def test_goodnight
    task = Goodnight.new :message => "goodnight"
    
    # a simple test
    assert_equal({:message  => 'goodnight'}, task.config)
    assert_equal "goodnight moon", task.process("moon")
  end
  
end