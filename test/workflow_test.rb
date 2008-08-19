require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/workflow'

# used in documentation
class SimpleSequence < Tap::Workflow
  config :factor, 1

  def workflow
    t1 = Tap::Task.new {|task, input| input += 5 }
    t2 = Tap::Task.new {|task, input| input += 3 }
    t3 = Tap::Task.new {|task, input| input *= factor }

    app.sequence(t1, t2, t3)
    self.entry_point = t1
    self.exit_point = t3
  end
end

class WorkflowTest < Test::Unit::TestCase
  include TapTestMethods

  acts_as_tap_test

  def test_documentation
    w = SimpleSequence.new
    w.enq(0)
    app.run
    assert_equal([8], app.results(w.exit_points))

    app.aggregator.clear

    w1 = SimpleSequence.new :factor => 1
    w2 = w1.initialize_batch_obj :factor => -1

    w1.enq(0)
    app.run
    assert_equal([8, -8], app.results(w1.exit_points, w2.exit_points))
  end

  #
  # declare test
  #
  
  class Declare < Tap::Workflow
    BLOCK = lambda {}
    
    declare :tap_task
    declare :task_with_block, &BLOCK
    declare :file_task, Tap::FileTask
    
    def workflow
      self.entry_point = Tap::Task.new
    end
  end
  
  def test_declare_task_makes_task_initializer
    w = Declare.new
    assert w.respond_to?(:tap_task)
    assert_equal Tap::Task, w.tap_task.class
  end
  
  def test_declare_task_returns_the_new_task_each_calls
    w = Declare.new
    t1 = w.tap_task
    assert_not_equal t1.object_id, w.tap_task.object_id
    
    t2 = w.tap_task('alt')
    assert_not_equal t2.object_id, w.tap_task('alt').object_id
  end

  def test_declared_tasks_are_named_with_input_or_method_name_by_default
    w = Declare.new
    assert_equal :tap_task, w.tap_task.name
    assert_equal 'alt', w.tap_task('alt').name
  end
  
  def test_declared_tasks_utilize_configurations_by_the_same_name
    w = Declare.new(:tap_task => {:key => 'value'})
    assert_equal({:key => 'value'}, w.tap_task.config)
    
    w.config['alt'] = {:key => 'another'}
    assert_equal({:key => 'another'}, w.tap_task('alt').config)
  end
  
  def test_initialization_of_a_task_using_non_hash_or_nil_configs_raises_error
    w = Declare.new :int => 2, :str => 'str', :hash => {}, :nil => nil
    
    assert_nothing_raised { w.tap_task(:hash) }
    assert_nothing_raised { w.tap_task(:nil) }
    assert_nothing_raised { w.tap_task(:non_existant) }
    assert_raise(ArgumentError) { w.tap_task(:int) }
    assert_raise(ArgumentError) { w.tap_task(:str) }
  end
  
  def test_initialization_initializes_class_using_block
    w = Declare.new
    
    t = w.tap_task
    assert_equal Tap::Task, t.class
    assert_equal nil, t.task_block
    
    t = w.task_with_block
    assert_equal Tap::Task, t.class
    assert_equal Declare::BLOCK, t.task_block
    
    t = w.file_task
    assert_equal Tap::FileTask, t.class
    assert_equal nil, t.task_block
  end
  
  def test_initialization_of_different_declarations_using_the_same_name_does_not_raise_an_error
    w = Declare.new
    w.tap_task(:name)
    
    assert_nothing_raised { w.tap_task(:name) }
    assert_nothing_raised { w.task_with_block(:name) }
    assert_nothing_raised { w.file_task(:name) }
  end
  
  def test_configurations_for_declared_task_may_not_be_set_through_config
    w = Declare.new
    w.config[:tap_task] = {:key => 'value'}
    t = w.tap_task
    
    assert_equal({:key => 'value'}, t.config)
    w.config[:tap_task][:key] = 'VALUE'
    assert_equal({:key => 'value'}, t.config)
  end

  #
  # initialization test
  #

  def test_workflow_raises_error_if_no_task_block_is_provided
    assert_raise(Tap::Workflow::WorkflowError) { Tap::Workflow.new() }
  end

  def test_workflow_raises_error_if_no_entry_point_is_defined
    assert_raise(Tap::Workflow::WorkflowError) do
      Tap::Workflow.new {|wf| }
    end
  end

  #
  # workflow test
  #

  class TestWorkflow < Tap::Workflow
    def t1
      @t1 ||= Tap::Task.new {|task, input| input += 1}
    end

    def t2
      @t2 ||= Tap::Task.new {|task, input| input += 1}
    end

    def workflow
      self.entry_point = t1
      app.sequence(t1, t2) 
      self.exit_point[:t2] = t2
    end
  end

  def test_workflow_method_defines_workflow
    w = TestWorkflow.new

    with_config :debug => true do
      w.enq(0)
      app.run
    end
    assert_audit_equal(ExpAudit[[nil,0],[w.t1,1],[w.t2,2]], app._results(w.exit_point[:t2]).first)
  end

  def test_workflow_sequences_execution_of_entry_point_if_entry_point_is_a_task
    t1 = Tap::Task.new(&add_one)
    t2 = Tap::Task.new(&add_one)
    wf = Tap::Workflow.new do |w|
      w.entry_point = t1
      w.app.sequence(t1, t2) 
    end

    assert_equal t1, wf.entry_point

    with_config :debug => true do
      wf.enq(0)
      app.run
    end
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t2,2]], app._results(t2).first) 
  end

  def test_workflow_forks_entry_points_if_entry_point_is_a_hash
    t1 = Tap::Task.new(&add_one)
    t2 = Tap::Task.new(&add_one)
    t3 = Tap::Task.new(&add_one)
    wf = Tap::Workflow.new do |w|
      w.entry_point[:t1] = t1
      w.entry_point[:t2] = t2
      w.app.sequence(t2, t3) 
    end

    assert_equal({:t1 => t1, :t2 => t2}, wf.entry_point)

    with_config :debug => true do
      wf.enq(0)
      app.run
    end
    assert_audit_equal(ExpAudit[[nil,0],[t1,1]], app._results(t1).first) 
    assert_audit_equal(ExpAudit[[nil,0],[t2,1],[t3,2]], app._results(t3).first) 
  end
end

