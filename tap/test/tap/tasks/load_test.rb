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
  
  def test_process_loads_input_from_filepaths
    path = method_root.prepare(:tmp, 'input.yml') do |file|
      file << {'one' => 1, 'two' => 2, 'three' => 3}.to_yaml
    end
    
    assert_equal({'one' => 1, 'two' => 2, 'three' => 3}, load.process(path))
  end
end