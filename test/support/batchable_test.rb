require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/batchable'

class BatchableTest < Test::Unit::TestCase

  class BatchableClass
    include Tap::Support::Batchable
  end
  
  attr_accessor :t
  
  def setup
    @t = BatchableClass.new
  end

  #
  # batch test
  #
  
  def test_batch_documentation
    t1 = Tap::Task.new
    t2 = Tap::Task.new
    t3 = t2.initialize_batch_obj
  
    Tap::Task.batch(t1, t2)
    assert_equal [t1,t2,t3], t3.batch
  end
  
  #
  # batched? test
  #
  
  def test_batched_returns_true_if_batch_size_is_greater_than_one
    assert !t.batched?
    assert_equal 1, t.batch.size
    
    t1 = t.initialize_batch_obj
    
    assert t.batched?
    assert t1.batched?
  end
  
  #
  # batch_index test
  #
  
  def test_batch_index_returns_the_index_of_the_task_in_batch
    t1 = t.initialize_batch_obj
    
    assert_equal [t, t1], t.batch
    assert_equal 0, t.batch_index
    assert_equal 1, t1.batch_index
  end
  
  #
  # initialize_batch_obj test
  #
  
  def test_created_batch_tasks_are_added_to_and_share_the_same_execute_batch
    assert_equal [t], t.batch
    
    t1 = t.initialize_batch_obj
    t2 = t1.initialize_batch_obj
    
    assert_equal [t, t1, t2], t.batch
    assert_equal t.batch.object_id, t1.batch.object_id
    assert_equal t.batch.object_id, t2.batch.object_id
  end

end
