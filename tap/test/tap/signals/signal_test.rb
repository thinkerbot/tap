require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/signals/signal'

class SignalTest < Test::Unit::TestCase
  Signal = Tap::Signals::Signal
  
  #
  # call tests
  #
  
  def test_call_calls_method_name_on_obj
    obj = Object.new
    sig = Signal.bind(:object_id).new(obj)
    assert_equal obj.object_id, sig.call
  end
  
  def test_call_calls_method_name_on_obj_with_args
    obj = []
    sig = Signal.bind(:<<).new(obj)
    
    sig.call([1])
    sig.call([2])
    sig.call([3])
    
    assert_equal [1,2,3], obj
  end
  
  def test_calls_raises_normal_errors_for_incorrrect_inputs
    sig = Signal.bind(:<<).new([])
    err = assert_raises(ArgumentError) { sig.call([1,2,3]) }
    assert_equal "wrong number of arguments (3 for 1)", err.message
  end
  
  def test_call_sends_inputs_to_block_before_calling_method
    sig = Signal.bind(:push) {|args| args.reverse }.new([])
    sig.call([1,2,3])
    
    assert_equal [3,2,1], sig.obj
  end
end