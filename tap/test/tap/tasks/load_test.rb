require File.join(File.dirname(__FILE__), '../../tap_test_helper') 
require 'tap/tasks/load'

class Tap::LoadTest < Test::Unit::TestCase
  include Tap::Tasks
  include MethodRoot
  include AppInstance
  
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
  
  class RequeLoad < Load
    attr_accessor :enqued
    
    def initialize(config={})
      @enqued = nil
      super(config)
    end
    
    def complete?(io, last)
      last == "last"
    end
    
    def enq(*inputs)
      @enqued = inputs
    end
  end
  
  def test_process_enques_self_unless_complete
    load = RequeLoad.new
    io = StringIO.new("one")
    
    assert_equal nil, load.enqued
    assert_equal("one", load.process(io))
    assert_equal [io], load.enqued
    
    load.enqued = nil
    io = StringIO.new("last")
    assert_equal("last", load.process(io))
    assert_equal nil, load.enqued
  end
end