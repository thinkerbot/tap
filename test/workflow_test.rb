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
  # initialization test
  #

  #
  # workflow test
  #
  
  class TestWorkflow < Tap::Workflow
    define(:t1) {|task, input| input += 1}
    define(:t2) {|task, input| input += 1}
 
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

