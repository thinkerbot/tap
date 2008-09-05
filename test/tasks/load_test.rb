require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/tasks/load'

class Tap::Tasks::LoadTest < Test::Unit::TestCase
  include Tap::Tasks
  
  acts_as_tap_test 
  
  #
  # process test
  #
  
  def test_process_loads_a_hash_and_flattens_results
    io = StringIO.new %Q{
key:
- 1
- 2
another:
- 3
}
    
    load = Load.new
    assert_equal [1,2,3], load.process(io).sort
  end
end