require File.join(File.dirname(__FILE__), '../../tap_test_helper') 
require 'tap/tasks/load'

class Tap::Tasks::LoadTest < Test::Unit::TestCase
  include Tap::Tasks
  
  acts_as_tap_test 
  
  attr_accessor :load
  
  def setup
    super
    @load = Load.new
  end
  
  def io(obj)
    StringIO.new(obj.to_yaml)
  end
  
  #
  # process test
  #
  
  def test_process_loads_input_as_yaml
    io = StringIO.new([1,2,3].to_yaml)
    assert_equal [1,2,3], load.process(io)
    
    io = StringIO.new({'one' => 1, 'two' => 2, 'three' => 3}.to_yaml)
    assert_equal({'one' => 1, 'two' => 2, 'three' => 3}, load.process(io))
  end
  
  def test_process_selects_array_entries_by_keys
    assert_equal [1,2], load.process(io([1,2,3]), 0, 1)
    assert_equal [2,3], load.process(io([1,2,3]), 1, 2)
    assert_equal [[1,2,3], [2,3]], load.process(io([1,2,3]), 0..2, 1..2)
    assert_equal [nil], load.process(io([1,2,3]), 100)
  end
  
  def test_process_selects_array_entries_matching_key_when_match
    load.match = true
    
    assert_equal ['abc'], load.process(io(['abc', 'xyz']), 'a')
    assert_equal ['abc', 'xyz'], load.process(io(['abc', 'xyz']), 'a', 'x')
    assert_equal ['abc', 'xyz'], load.process(io(['abc', 'xyz']), 'a|x')
    assert_equal [], load.process(io(['abc', 'xyz']), 'q')
  end
  
  def test_process_selects_hash_entries_using_keys
    assert_equal [1,2], load.process(io({'one' => 1, 'two' => 2, 'three' => 3}), 'one', 'two')
    assert_equal [2,3], load.process(io({'one' => 1, 'two' => 2, 'three' => 3}), 'two', 'three')
    assert_equal [nil], load.process(io({'one' => 1, 'two' => 2, 'three' => 3}), 'five')
  end
  
  def test_process_selects_hash_values_when_key_matches_key_when_match
    load.match = true
    
    assert_equal [1], load.process(io({'one' => 1, 'two' => 2, 'three' => 3}), 'on')
    assert_equal [1,2], load.process(io({'one' => 1, 'two' => 2, 'three' => 3}), 'on', 'wo').sort
    assert_equal [1,2], load.process(io({'one' => 1, 'two' => 2, 'three' => 3}), 'o').sort
    assert_equal [], load.process(io({'one' => 1, 'two' => 2, 'three' => 3}), 'q')
  end
  
end