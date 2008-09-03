require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/app'
require 'stringio'
require 'logger'

class AppTest < Test::Unit::TestCase
  include Tap
  include TapTestMethods
  
  acts_as_tap_test
  
  def app_config
    { :root => method_root, 
      :directories => trs.directories,
      :absolute_paths => trs.absolute_paths}
  end
  
  def setup
    super
    app.root = trs.root
  end
  
  #
  # instance tests
  #
  
  def test_instance_returns_current_instance_or_a_default_app
    a = App.new
    App.instance = a
    assert_equal a, App.instance
    
    App.instance = nil
    assert_equal App, App.instance.class
  end
  
  def test_instance_initializes_new_App_if_not_set
    Tap::App.instance = nil
    assert Tap::App.instance.kind_of?(Tap::App)
  end
  
  #
  # helpers
  #

  def test_app_documentation
    t1 = Task.new {|task, input| input += 1 }
    t1.enq(0)
    app.enq(t1, 1)
  
    app.run
    assert_equal [1, 2], app.results(t1)
    
    ########
    
    app.aggregator.clear
  
    t2 = Task.new {|task, input| input += 10 }
    t1.on_complete {|_result| t2.enq(_result) }
  
    t1.enq 0
    t1.enq 10
  
    app.run
    assert_equal [], app.results(t1)
    assert_equal [11, 21], app.results(t2)
    
    ########
    
    array = []
    t1 = Task.new {|task, *inputs| array << inputs }
    t2 = Task.new {|task, *inputs| array << inputs }
  
    t1.depends_on(t2,1,2,3)
    t1.enq(4,5,6)
  
    app.run
    assert_equal [[1,2,3], [4,5,6]], array
   
    t1.enq(7,8)
    app.run
    assert_equal [[1,2,3], [4,5,6], [7,8]], array
    
    ########
  
    t1 = Task.new  {|task, input| input += 1 }
    t2 = Task.new  {|task, input| input += 10 }
    assert_equal [t1, t2], Task.batch(t1, t2)
  
    t1.enq 0
  
    app.run
    assert_equal [1], app.results(t1)
    assert_equal [10], app.results(t2)
    
    ########
  
    array = []
    m = array._method(:push)
     
    app.enq(m, 1)
    app.mq(array, :push, 2)
  
    assert array.empty?
    app.run
    assert_equal [1, 2], array
    
    ########
  
    t1 = Tap::Task.new {|task, input| input += 1 }
    t1.name = "add_one"
  
    t2 = Tap::Task.new {|task, input| input += 5 }
    t2.name = "add_five"
  
    t1.on_complete do |_result|
      # _result is the audit; use the _current method
      # to get the current value in the audit trail
  
      _result._current < 3 ? t1.enq(_result) : t2.enq(_result)
    end
    
    t1.enq(0)
    t1.enq(1)
    t1.enq(2)
  
    app.run
    assert_equal [8,8,8], app.results(t2)

    str = StringIO.new("")
    app._results(t2).each do |_result|
      str.puts "How #{_result._original} became #{_result._current}:"
      str.puts _result._to_s
      str.puts
    end
  
    expected = %Q{
How 2 became 8:
o-[] 2
o-[add_one] 3
o-[add_five] 8

How 1 became 8:
o-[] 1
o-[add_one] 2
o-[add_one] 3
o-[add_five] 8

How 0 became 8:
o-[] 0
o-[add_one] 1
o-[add_one] 2
o-[add_one] 3
o-[add_five] 8
}
    assert_equal expected.strip, str.string.strip
  end
  
  #
  #  State test
  #
  
  def test_state_str_documentation
    assert_equal 'READY', App::State.state_str(0)
    assert_nil App::State.state_str(12)
  end
  
  # 
  # initialization tests
  #
  
  def test_default_app
    app = App.new
    
    assert_equal Dir.pwd, app.root
    assert_equal({}, app.directories)

    assert_equal(Support::ExecutableQueue, app.queue.class)
    assert app.queue.empty?
    
    assert_equal(Support::Aggregator, app.aggregator.class)
    assert app.aggregator.empty?
    
    assert_equal App::State::READY, app.state
  end
  
  #
  # set logger tests
  #
  
  def test_set_logger_sets_logger_level_to_debug_if_debug_is_true
    logger = Logger.new($stdout)
    logger.level = Logger::INFO
    assert_equal Logger::INFO, logger.level
    
    app.debug = true
    assert app.debug?
    
    app.logger = logger
    assert_equal Logger::DEBUG, logger.level
  end
  
  #
  # config_filepath test
  #
  
  def test_config_filepath_joins_config_dir_and_input
    assert_equal File.join(app['config'], "task/name.yml"), app.config_filepath("task/name")
  end
  
  def test_config_filepath_is_nil_for_nil
    assert_equal nil, app.config_filepath(nil)
  end
  
  def test_config_filepath_stringifies_input
    assert_equal File.join(app['config'], "task.yml"), app.config_filepath(:task)
  end
  
  #
  # ready test
  #
  
  def test_ready_sets_state_to_READY_unless_state_is_RUN
    app.instance_variable_set('@state', App::State::STOP)
    app.ready
    assert_equal App::State::READY, app.state
    
    app.instance_variable_set('@state', App::State::RUN)
    app.ready
    assert_equal App::State::RUN, app.state
  end
  
  def test_ready_returns_self
    assert_equal app, app.ready
  end
  
  #
  # run tests
  #

  def test_run_single_task
    t = Task.new(&add_one)
    t.enq 1
    app.run

    assert_audit_equal(ExpAudit[[nil, 1], [t,2]], app._results(t).first)
    assert_equal [1], runlist
  end
  
  def test_run_executes_each_task_in_queue_in_order
    Task.new(&echo).enq 1
    Task.new(&echo).enq 2
    Task.new(&echo).enq 3
    
    app.run

    assert_equal [[1],[2],[3]], runlist
  end
  
  def test_run_returns_self_when_running
    queue_before = nil
    queue_after = nil
    t1 = Task.new do |task| 
      queue_before = app.queue.to_a
      app.run
      queue_after = app.queue.to_a
    end
    t2 = Task.new
    
    t1.enq
    t2.enq
    app.run
    
    assert_not_nil queue_before
    assert_not_nil queue_after
    assert_equal queue_before, queue_after
  end
  
  def test_run_returns_self
    assert_equal app, app.run
  end

  #
  # info tests
  #
  
  def test_info_provides_information_string
    assert_equal 'state: 0 (READY) queue: 0 results: 0', app.info
  end

  #
  # enq test
  #
  
  def test_enq
    t = Task.new
    assert app.queue.empty?
    app.enq(t)
    assert_equal [[t, []]], app.queue.to_a
  end
  
  def test_enq_enques_each_task_in_task_batch_with_the_same_inputs
    t1 = Task.new
    t2 = t1.initialize_batch_obj
    
    assert app.queue.empty?
    app.enq(t1)
    assert_equal [[t1, []], [t2, []]], app.queue.to_a
    
    app.enq(t2,1,2,3)
    assert_equal [
      [t1, []], [t2, []],
      [t1, [1,2,3]], [t2, [1,2,3]]
    ], app.queue.to_a
  end
  
  def test_enq_allows_Executable_methods
    m = []._method(:push)
    assert app.queue.empty?
    app.enq(m)
    assert_equal [[m, []]], app.queue.to_a
  end
  
  def test_enq_returns_enqued_task
    t = Task.new
    assert_equal t, app.enq(t)
  end
  
  #
  # mq test
  #
  
  def test_mq
    a = []
    assert app.queue.empty?
    m = app.mq(a, :push, 1, 2)
    assert_equal [[m, [1,2]]], app.queue.to_a
  end

  #
  # sequence tests
  #
  
  def test_sequence
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    
    app.sequence([t1,t2])
    t1.enq 0
    app.run

    assert_equal [0,1], runlist
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t2,2]], app._results(t2).first)
  end

  def test_run_sequence_from_trailing_task_does_not_invoke_prior_tasks
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    
    app.sequence([t1,t2])
    
    t2.enq 1
    app.run

    assert_equal [1], runlist
    assert_equal 0, app._results(t1).length
    assert_audit_equal(ExpAudit[[nil,1],[t2,2]], app._results(t2).first)
  end

  #
  # fork tests
  #
  
  def test_fork
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    t3 = Task.new(&add_one)
    
    app.fork(t1, [t2, t3])
    
    t1.enq 0
    app.run
  
    assert_equal [0,1,1], runlist
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t2,2]], app._results(t2).first)
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t3,2]], app._results(t3).first)
  end
  
  #
  # merge tests
  #
  
  def test_merge
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    t3 = Task.new(&add_one)
  
    app.merge(t3, [t1, t2])

    t1.enq 0
    t2.enq 10
    app.run

    assert_equal [0,10,1,11], runlist
    
    assert_audits_equal([
      ExpAudit[[nil,0],[t1,1],[t3,2]],
      ExpAudit[[nil,10],[t2,11],[t3,12]]
    ], app._results(t3))
  end
  
  #
  # sync_merge tests
  #
  
  def test_sync_merge
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    t3 = Task.new(&echo)
  
    app.sync_merge(t3, [t1, t2])

    t1.enq 0
    t2.enq 10
    app.run

    assert_equal [0,10,[[1,11]]], runlist

    ea = ExpAudit[[nil,0],[t1,1]]
    eb = ExpAudit[[nil,10],[t2,11]]

    assert_audits_equal([
      ExpAudit[ExpMerge[ea,eb], [t3,[[1,11]]]]
    ], app._results(t3))
  end
  
  def test_sync_merge_raises_error_if_target_cannot_be_enqued_before_a_source_executes_twice
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    t3 = Task.new(&echo)
  
    app.sync_merge(t3, [t1, t2])

    t1.enq 0
    t1.enq 1
    t2.enq 10
    with_config :debug => true do
      assert_raise(RuntimeError) { app.run }
    end
    assert_equal [0,1], runlist
  end
  
  #
  # switch tests
  #
  
  def test_switch
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    t3 = Task.new(&add_one)
    
    index = nil
    app.switch(t1, [t2,t3]) do |_results|
      index
    end
    
    # pick t2
    index = 0
    t1.enq 0
    app.run

    assert_equal [0,1], runlist
    assert app._results(t1).empty?
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t2,2]], app._results(t2).first)
    assert app._results(t3).empty?
    
    # now pick t3
    index = 1
    t1.enq 0
    app.run

    assert_equal [0,1,0,1], runlist
    assert app._results(t1).empty?
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t2,2]], app._results(t2).first)
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t3,2]], app._results(t3).first)
    
    # now skip (aggregate result)
    index = nil
    t1.enq 0
    app.run

    assert_equal [0,1,0,1,0], runlist
    assert_audit_equal(ExpAudit[[nil,0],[t1,1]], app._results(t1).first)
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t2,2]], app._results(t2).first)
    assert_audit_equal(ExpAudit[[nil,0],[t1,1],[t3,2]], app._results(t3).first)
  end
  
  def test_switch_raises_error_for_out_of_bounds_index
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    t3 = Task.new(&add_one)
    
    app.switch(t1, [t2,t3]) do |_results|
      100
    end
    
    t1.enq 0
    with_config :debug => true do
      assert_raise(RuntimeError) { app.run }
    end
  end

  #
  # run batched task tests
  #

  def test_run_batched_task
    t1 = Task.new(:factor => 10) do |task, input|
      runlist << input
      input + task.config[:factor]
    end
    t2 = t1.initialize_batch_obj(:factor => 22)

    with_config :debug => true do
      t1.enq 0
      app.run
    end

    # note same input fed to each template 
    assert_equal [0,0], runlist

    assert_audits_equal([
      ExpAudit[[nil,0],[t1,10]],
      ExpAudit[[nil,0],[t2,22]]
    ], app._results(*t1.batch))
  end
   
  def test_run_batched_task_with_existing_audit_trails
    t1 = Task.new(:factor => 10) do |task, input|
      runlist << input
      input + task.config[:factor]
    end
    t2 = t1.initialize_batch_obj(:factor => 22)

    a = Support::Audit.new(0, :a)
    with_config :debug => true do
      t1.enq a
      app.run
    end

    # note same input fed to each template 
    assert_equal [0,0], runlist

    assert_audits_equal([
      ExpAudit[[:a,0],[t1,10]],
      ExpAudit[[:a,0],[t2,22]]
    ], app._results(t1.batch))
  end
  
  def test_fork_in_batched_task
    t1, t2, t3 = Array.new(3) do
      t = Task.new(:factor => 10) do |task, input|
        runlist << input
        input + task.config[:factor]
      end
      t.initialize_batch_obj(:factor => 22)
    end
    
    app.fork(t1, [t2, t3])
    with_config :debug => true do
      t1.enq 0
      app.run
    end
    
    assert_equal [
      0,0,             # once for each t1 template
      10,10, 10,10,    # first result into t2, t3 tasks
      22,22, 22,22     # second result into t2, t3 tasks
    ], runlist
  
    t1_0 = t1.batch[0] 
    t1_1 = t1.batch[1]
    
    t2_0 = t2.batch[0] 
    t2_1 = t2.batch[1] 
    
    t3_0 = t3.batch[0] 
    t3_1 = t3.batch[1]
    
    # check t2 results
    assert_audits_equal([
      ExpAudit[[nil,0],[t1_0,10],[t2_0,20]],
      ExpAudit[[nil,0],[t1_1,22],[t2_0,32]],
      ExpAudit[[nil,0],[t1_0,10],[t2_1,32]],
      ExpAudit[[nil,0],[t1_1,22],[t2_1,44]]
    ], app._results(t2.batch))
    
    # check t3 results
    assert_audits_equal([
      ExpAudit[[nil,0],[t1_0,10],[t3_0,20]],
      ExpAudit[[nil,0],[t1_1,22],[t3_0,32]],
      ExpAudit[[nil,0],[t1_0,10],[t3_1,32]], 
      ExpAudit[[nil,0],[t1_1,22],[t3_1,44]]
    ], app._results(t3.batch))
  end
  
  def test_merge_batched_task
    t1, t2, t3 = Array.new(3) do
      t = Task.new(:factor => 10) do |task, input|
        runlist << input
        input + task.config[:factor]
      end
      t.initialize_batch_obj(:factor => 22)
    end
  
    app.merge(t3, [t1, t2])
    t1.enq(0)
    t2.enq(2)
    with_config :debug => true do
      app.run
    end
  
    assert_equal [
      0,0,                  # 1 input to each t1
      2,2,                  # 2 input to each t2
      10,10,22,22,          # t1 outputs to each t3
      12,12,24,24           # t2 outputs to each t3
    ], runlist
  
    t1_0 = t1.batch[0] 
    t1_1 = t1.batch[1]
  
    t2_0 = t2.batch[0] 
    t2_1 = t2.batch[1] 
  
    t3_0 = t3.batch[0] 
    t3_1 = t3.batch[1]
  
    # check results
    assert_audits_equal([
      ExpAudit[[nil,0],[t1_0,10],[t3_0,20]], 
      ExpAudit[[nil,0],[t1_1,22],[t3_0,32]],
      ExpAudit[[nil,2],[t2_0,12],[t3_0,22]],
      ExpAudit[[nil,2],[t2_1,24],[t3_0,34]],
      ExpAudit[[nil,0],[t1_0,10],[t3_1,32]],
      ExpAudit[[nil,0],[t1_1,22],[t3_1,44]],
      ExpAudit[[nil,2],[t2_0,12],[t3_1,34]],
      ExpAudit[[nil,2],[t2_1,24],[t3_1,46]]
    ], app._results(t3.batch))
  end
  
  # TODO - test sync_merge, switch batched tasks
  
  #
  # other run tests
  #
  
  def test_feedback_loop
    t1 = Task.new(&add_one)
    t2 = Task.new(&add_one)
    t3 = Task.new(&add_one)
  
    # distribute the results of t1 based on value
    t1.on_complete do |result|
      if result._current < 4
        t2.enq result
      else
        t3.enq result  
      end
    end
  
    # set the results of t2 to reinvoke the workflow
    app.sequence([t2, t1])
    
    with_config :debug => true do
      t1.enq(0)
      t1.enq(2)
      app.run
    end
    
    assert_equal [0,2,1,3,2,4,3,5,4,5], runlist

    assert_audits_equal([
      ExpAudit[[nil,2],[t1,3],[t2,4],[t1,5],[t3,6]],
      ExpAudit[[nil,0],[t1,1],[t2,2],[t1,3],[t2,4],[t1,5],[t3,6]]
    ], app._results(t3.batch))
  end
  
  #
  # _results test
  #

  def test__results_returns_audited_results_for_listed_sources
    t1 = Task.new {|task, input| input + 1 }
    a1 = t1._execute(0)
    
    t2 = Task.new {|task, input| input + 1 } 
    a2 = t2._execute(1)
    
    app.aggregator.store a1
    app.aggregator.store a2
    assert_equal [a1], app._results(t1)
    assert_equal [a2, a1], app._results(t2, t1)
    assert_equal [a1, a1], app._results(t1, t1)
  end
  
  #
  # results test
  #
  
  def test_results_documentation
    t1 = Task.new  {|task, input| input += 1 }
    t2 = Task.new  {|task, input| input += 10 }
    t3 = t2.initialize_batch_obj
    
    t1.enq(0)
    t2.enq(1)
    
    app.run
    assert_equal [1, 11, 11], app.results(t1, t2.batch)
    assert_equal  [11, 1], app.results(t2, t1)
  end
  
  def test_results_returns_current_values_of__results
    t1 = Task.new {|task, input| input + 1 }
    a1 = t1._execute(0)
    
    t2 = Task.new {|task, input| input + 1 } 
    a2 = t2._execute(1)
    
    app.aggregator.store a1
    app.aggregator.store a2
    assert_equal [1], app.results(t1)
    assert_equal [2, 1], app.results(t2, t1)
    assert_equal [1, 1], app.results(t1, t1)
  end
  
  def test_results_for_various_objects
    t1 = Task.new {|task, input| input}

    t1.enq({:key => 'value'})
    t1.enq([1,2,3])
    t1.enq(2)
    t1.enq("str")
    
    app.run
    assert_equal [{:key => 'value'}, [1,2,3], 2, "str"], app.results(t1)
  end
  
  #
  # error tests
  #
  
  def set_stringio_logger
    output = StringIO.new('')
    app.logger = Logger.new(output)
    app.logger.formatter = Tap::App::DEFAULT_LOGGER.formatter
    output.string
  end
  
  def test_unhandled_exception_is_logged_by_default
    task = Task.new {|t| raise "error"}
     
    string = set_stringio_logger
    task.enq
    app.run
    
    assert string =~ /RuntimeError error/
  end
  
  def test_terminate_errors_are_ignored
    was_in_block = false
    task = Task.new do |t| 
      was_in_block = true
      raise Tap::App::TerminateError
      flunk "should have been terminated"
    end
     
    task.enq
    assert_nothing_raised { app.run }
    assert was_in_block
  end
  
  #
  # benchmarks
  #
  
  def test_run_speed
    t = Tap::Task.new 
    benchmark_test(20) do |x|
      n = 10000
          
      x.report("10k enq ") { n.times { t.enq(1) } }
      x.report("10k run ") { n.times {}; app.run }
      x.report("10k _execute ") { n.times { t._execute(1) } }
    end
  end
end
