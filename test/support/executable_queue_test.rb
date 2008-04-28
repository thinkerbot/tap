require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/executable_queue'

class ExecutableQueueTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_accessor :m, :queue
 
  def setup
    @m = Object.new.extend Executable
    @queue = ExecutableQueue.new
  end
  
  #
  # initialization tests
  #
  
  def test_initialize
    q = ExecutableQueue.new
    assert q.empty?
  end
  
  #
  # size, clear, empty? tests
  #
  
  def test_size_return_number_of_tasks
    assert_equal 0, queue.size
    queue.enq m, []
    assert_equal 1, queue.size
  end

  def test_empty_is_true_if_tasks_is_empty
    assert queue.empty?
    queue.enq m, []
    assert !queue.empty?
  end
  
  def test_clear_resets_tasks_and_task_inputs
    assert_equal([], queue.to_a)
    
    queue.enq m, []
    queue.clear
    
    assert_equal([], queue.to_a)
  end
  
  def test_clear_returns_existing_queue_as_an_array
    assert_equal([], queue.to_a)
    
    queue.enq m, []
    assert_equal [[m, []]], queue.clear
  end
  
  #
  # queue test
  #
  
  def test_enq_pushes_task_and_inputs_onto_queue
    assert_equal [], queue.to_a
    
    queue.enq(m, [1])
    assert_equal [[m,[1]]], queue.to_a

    queue.enq(m, [2])
    assert_equal [[m,[1]], [m,[2]]], queue.to_a
  end
  
  def test_enq_raises_error_for_non_task_methods
    assert_raise(RuntimeError) { queue.enq(method(:setup), [1]) }
  end
  
  #
  # unshift test
  #
  
  def test_unshift
    assert_equal [], queue.to_a
    
    queue.unshift(m, [1])
    assert_equal [[m,[1]]], queue.to_a

    queue.unshift(m, [2])
    assert_equal [[m,[2]], [m,[1]]], queue.to_a
  end

  def test_unshift_raises_error_for_non_task_methods
    assert_raise(RuntimeError) { queue.unshift(method(:setup), [1]) }
  end
  
  #
  # deq test
  #
  
  def test_deq
    queue.enq(m, [1])
    queue.enq(m, [2])
    
    assert_equal [m, [1]], queue.deq
    assert_equal [m, [2]], queue.deq
  end
  
end