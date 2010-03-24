require File.expand_path('../../../tap_test_helper', __FILE__) 
require 'tap/tasks/load'
require 'tap/test/unit'

class Tap::LoadTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  Load = Tap::Tasks::Load
  
  attr_accessor :load
  
  def setup
    super
    @load = Load.new
  end
  
  def io(obj)
    StringIO.new YAML.dump(obj)
  end
  
  #
  # process test
  #
  
  def test_process_reads_input
    str = YAML.dump({'one' => 1, 'two' => 2, 'three' => 3})
    io = StringIO.new(str)
    assert_equal(str, load.process(io))
  end

  def test_process_return_string_inputs
    assert_equal("string", load.process("string"))
  end
  
  def test_process_closes_io_when_use_close_is_true
    io = StringIO.new
    load.process(io)
    assert !io.closed?
    
    load.use_close = true
    load.process(io)
    assert io.closed?
  end
end