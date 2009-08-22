require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/signals/signal'

class SignalTest < Test::Unit::TestCase
  Signal = Tap::Signals::Signal
  
  attr_reader :obj
  
  def setup
    @obj = Object.new
  end
  
  #
  # bind tests
  #
  
  def test_bind_sets_block_as_process
    sig = Signal.bind() {|args| args.reverse }.new(obj)
    assert_equal [3,2,1], sig.process([1,2,3])
  end
  
  def test_bind_sets_call_to_process_inputs
    sig = Signal.bind() {|args| args.reverse }.new(obj)
    assert_equal [3,2,1], sig.call([1,2,3])
  end
  
  def test_bind_sets_call_to_call_method_name_on_obj_when_specified
    sig = Signal.bind(:object_id).new(obj)
    assert_equal obj.object_id, sig.call([])
  end
  
  def test_method_name_is_called_with_inputs
    obj = []
    sig = Signal.bind(:<<).new(obj)
    
    sig.call([1])
    sig.call([2])
    sig.call([3])
    
    assert_equal [1,2,3], obj
  end
  def test_inputs_are_processed_before_calling_method_name
    sig = Signal.bind(:push) {|args| args.reverse }.new([])
    sig.call([1,2,3])
    
    assert_equal [3,2,1], sig.obj
  end
  
  def test_call_raises_normal_errors_for_incorrrect_inputs
    sig = Signal.bind(:<<).new([])
    err = assert_raises(ArgumentError) { sig.call([1,2,3]) }
    assert_equal "wrong number of arguments (3 for 1)", err.message
  end

end