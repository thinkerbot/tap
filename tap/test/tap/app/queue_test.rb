require File.expand_path('../../../test_helper', __FILE__)
require 'tap/app/queue'

class QueueTest < Test::Unit::TestCase
  Queue = Tap::App::Queue
  
  attr_accessor :m, :queue
 
  def setup
    @m = :method
    @queue = Queue.new
  end
  
  #
  # initialization tests
  #
  
  def test_initialize
    q = Queue.new
    assert_equal 0, q.size
  end
  
  #
  # enq test
  #
  
  def test_enq_pushes_task_and_input_onto_queue
    assert_equal [], queue.to_a
    
    queue.enq(m, :a)
    assert_equal [[m, :a]], queue.to_a

    queue.enq(m, :b)
    assert_equal [[m, :a], [m, :b]], queue.to_a
  end

  #
  # unshift test
  #
  
  def test_unshift
    assert_equal [], queue.to_a
    
    queue.unshift(m, :a)
    assert_equal [[m, :a]], queue.to_a

    queue.unshift(m, :b)
    assert_equal [[m, :b], [m, :a]], queue.to_a
  end

  #
  # deq test
  #
  
  def test_deq
    queue.enq(m, :a)
    queue.enq(m, :b)
    
    assert_equal [m, :a], queue.deq
    assert_equal [m, :b], queue.deq
  end
  
  #
  # size tests
  #
  
  def test_size_return_number_of_tasks
    assert_equal 0, queue.size
    queue.enq m, []
    assert_equal 1, queue.size
  end
  
  #
  # clear tests
  #
  
  def test_clear_resets_tasks_and_task_inputs
    assert_equal([], queue.to_a)
    
    queue.enq m, []
    queue.clear
    
    assert_equal([], queue.to_a)
  end
  
  def test_clear_returns_existing_queue
    assert_equal([], queue.to_a)
    
    queue.enq m, :a
    queue.enq m, :b
    assert_equal [[m, :a], [m, :b]], queue.clear
  end
  
  #
  # to_a test
  #
  
  def test_to_a_returns_an_array_of_enqued_methods_and_entries
    queue.enq m, :a
    queue.enq m, :b
    
    assert_equal [
      [m, :a],
      [m, :b]
    ], queue.to_a
  end
end