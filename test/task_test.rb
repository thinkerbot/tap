require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/task'

# used in documentation test
class ConfiguredTask < Tap::Task
  config :one, 'one'
  config :two, 'two'
end
class ValidatingTask < Tap::Task
  config :string, 'str', &c.check(String)
  config :integer, 1, &c.yaml(Integer)
end 
class SubclassTask < Tap::Task
  attr_accessor :array
  def initialize(*args)
    @array = []
    super
  end

  def initialize_copy(orig)
    @array = orig.array.dup
    super
  end
end

class TaskTest < Test::Unit::TestCase
  include Tap
  include TapTestMethods
  
  acts_as_tap_test
  attr_accessor :t
  
  def setup
    super
    @t = Task.new
    app.root = trs.root
  end
  
  def test_documentation
    t = ConfiguredTask.new
    assert_equal("configured_task", t.name)
    assert_equal({:one => 'one', :two => 'two'}, t.config)           
  
    t = ValidatingTask.new
    assert_raise(Support::Validation::ValidationError) { t.string = 1 }
    assert_raise(Support::Validation::ValidationError) { t.integer = 1.1 }
  
    t.integer = "1"
    assert_equal 1, t.integer
    
    t = ConfiguredTask.new({:one => 'ONE', :three => 'three'}, "example")
    assert_equal "example", t.name
    assert_equal({:one => 'ONE', :two => 'two', :three => 'three'}, t.config)
    
    ###
    app = Tap::App.instance
    t1 = Tap::Task.new(:key => 'one') do |task, input| 
      input + task.config[:key]
    end
    assert_equal [t1], t1.batch
  
    t2 = t1.initialize_batch_obj(:key => 'two')
    assert_equal [t1, t2], t1.batch
    assert_equal [t1, t2], t2.batch
    
    t1.enq 't1_by_'
    t2.enq 't2_by_'
    app.run
  
    assert_equal ["t1_by_one", "t2_by_one"], app.results(t1)
    assert_equal ["t1_by_two", "t2_by_two"], app.results(t2)
    
    ###
    t1 = SubclassTask.new
    t2 = t1.initialize_batch_obj
    assert_equal true, t1.array == t2.array
    assert_equal false, t1.array.object_id == t2.array.object_id
  end
  
  #
  # initialization tests
  #
  
  def test_default_initialization
    assert_equal App.instance, t.app
    assert_equal({}, t.config)
    assert_equal [t], t.batch
    assert_nil t.task_block
    assert_equal "tap/task", t.name
  end
  
  def test_initialization_inputs
    a = App.new
    b = lambda {}
    
    t = Task.new({:key => 'value'}, "name", a, &b) 
    assert_equal "name", t.name
    assert_equal({:key => 'value'}, t.config)
    assert_equal a, t.app
    assert_equal b, t.task_block
  end

  def test_task_init_speed
    benchmark_test(20) do |x|
      x.report("10k") { 10000.times { Task.new } }
      x.report("10k {}") { 10000.times { Task.new {} } }
      x.report("10k ({},name) {}") { 10000.times { Task.new({},'name') {} } }
    end
  end

  def test_by_default_tasks_share_application_instance
    t1 = Task.new
    t2 = Task.new
    
    assert_equal t1.app, t2.app
    assert_equal App.instance, t1.app
  end
  
  #
  # config tests
  #
  
  # def test_config_is_loaded_from_config_file
  #   t = Task.new "configured"
  #   assert File.exists?(t.config_file)
  #   assert_equal "key: value", File.read(t.config_file)
  #   assert_equal({:key => 'value'}, t.config)
  # end
  # 
  # def test_batched_tasks_are_defined_with_corresponding_configs_for_batched_config_files
  #   t = Task.new "batched"
  #   assert File.exists?(t.config_file)
  #   assert_equal "- key: first\n- key: second", File.read(t.config_file)
  #   
  #   assert_equal 2, t.batch.size
  #   
  #   t1, t2 = t.batch
  #   assert_equal({:key => 'first'}, t1.config)
  #   assert_equal({:key => 'second'}, t2.config)
  # end
  # 
  # def test_configs_are_merged_to_each_batched_task
  #   t = Task.new "batched", :another => 'value'
  #   t1, t2 = t.batch
  #   assert_equal({:key => 'first', :another => 'value'}, t1.config)
  #   assert_equal({:key => 'second', :another => 'value'}, t2.config)
  # end
  
  #
  # enq test
  #
  
  def test_enq_enqueues_task_to_app_queue_with_inputs
    assert t.app.queue.empty?
    
    t.enq 1
    
    assert_equal 1, t.app.queue.size
    assert_equal [[t, [1]]], t.app.queue.to_a
    
    t.enq 1
    t.enq 2
    
    assert_equal [[t, [1]], [t, [1]], [t, [2]]], t.app.queue.to_a
  end

  def test_enq_enqueues_task_batch
    t2 = t.initialize_batch_obj
    
    assert t.app.queue.empty?
    assert_equal 2, t.batch.size
    
    t.enq 1
    
    assert_equal 2, t.app.queue.size
    assert_equal [[t, [1]], [t2, [1]]], t.app.queue.to_a
  end
  
  def test_unbatched_enq_only_enqueues_task
    t2 = t.initialize_batch_obj
    
    assert_equal 2, t.batch.size
    assert t.app.queue.empty?
    t.unbatched_enq 1
    
    assert_equal 1, t.app.queue.size
    assert_equal [[t, [1]]], t.app.queue.to_a
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_completes_task_batch
    t2 = t.initialize_batch_obj
    
    assert_nil t.on_complete_block
    assert_nil t2.on_complete_block

    b = lambda {}
    t.on_complete(&b)
    
    assert_equal b, t.on_complete_block
    assert_equal b, t2.on_complete_block
  end
  
  def test_unbatched_on_complete_only_completes_task
    t2 = t.initialize_batch_obj
    
    assert_nil t.on_complete_block
    assert_nil t2.on_complete_block

    b = lambda {}
    t.unbatched_on_complete(&b)
    
    assert_equal b, t.on_complete_block
    assert_nil t2.on_complete_block
  end
  
  #
  # multithread= test
  #
  
  def test_set_multithread_sets_multithread_for_task_batch
    t2 = t.initialize_batch_obj
    
    assert !t.multithread
    assert !t2.multithread

    t.multithread = true
    
    assert t.multithread
    assert t2.multithread
  end
  
  def test_unbatched_set_multithread_sets_multithread_for_task_only
    t2 = t.initialize_batch_obj
    
    assert !t.multithread
    assert !t2.multithread

    t.unbatched_multithread = true
    
    assert t.multithread
    assert !t2.multithread
  end
  
  #
  # process test
  #
  
  class TaskWithTwoInputsForProcessDoc < Tap::Task
    def process(a, b)
      [b,a]
    end
  end
  
  def test_process_documentation
    t = TaskWithTwoInputsForProcessDoc.new
    t.enq(1,2).enq(3,4)
    t.app.run
    assert_equal [[2,1], [4,3]], t.app.results(t)

    t = Task.new {|task, a, b| [b,a] }
    t.enq(1,2).enq(3,4)
    t.app.run
    assert_equal [[2,1], [4,3]], t.app.results(t)
  end
  
  def test_process_calls_task_block_with_input
    b = lambda do |task, input|
      runlist << input
      input += 1
    end
    t = Task.new(&b)
  
    assert_equal b, t.task_block
    assert_equal 2, t.process(1)
    assert_equal [1], runlist
  end
  
  def test_process_returns_inputs_if_task_block_is_not_set
    t = Task.new
    assert_nil t.task_block
    assert_equal [1,2,3], t.process(1,2,3)
  end

end