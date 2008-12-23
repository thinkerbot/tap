require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/app'
require 'stringio'
require 'logger'

class AppTest < Test::Unit::TestCase
  include Tap
  include TapTestMethods
  
  acts_as_tap_test
  
  def app_config
    method_root.config.to_hash
  end
  
  def setup
    super
    app.root = ctr.root
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
  # documentation test
  #

  def test_app_documentation
    t0 = Task.intern {|task, input| "#{input}.0" }
    t0.enq('a')
    app.enq(t0, 'b')
  
    app.run
    assert_equal ['a.0', 'b.0'], app.results(t0)
    
    ####
    app.aggregator.clear
  
    t1 = Task.intern {|task, input| "#{input}.1" }
    t0.on_complete {|_result| t1.enq(_result) }
    t0.enq 'c'
  
    app.run
    assert_equal [], app.results(t0)
    assert_equal ['c.0.1'], app.results(t1)
    
    ####
    runlist = []
    t0 = Task.intern {|task| runlist << task }
    t1 = Task.intern {|task| runlist << task }
  
    t0.depends_on(t1)
    t0.enq
  
    app.run
    assert_equal [t1, t0], runlist
  
    t0.enq
    app.run
    assert_equal [t1, t0, t0], runlist
    
    ####
    t0 = Task.intern  {|task, input| "#{input}.0" }
    t1 = Task.intern  {|task, input| "#{input}.1" }
  
    t0.batch_with(t1)
    t0.enq 'a'
    t1.enq 'b'
  
    app.run
    assert_equal ['a.0', 'b.0'], app.results(t0)
    assert_equal ['a.1', 'b.1'], app.results(t1)
    
    ####
    array = []
  
    # longhand
    m = array._method(:push)
    m.enq(1)
  
    # shorthand
    app.mq(array, :push, 2)
  
    assert array.empty?
    app.run
    assert_equal [1, 2], array
    
    ####
    add_one  = Tap::Task.intern({}, 'add_one')  {|task, input| input += 1 }
    add_five = Tap::Task.intern({}, 'add_five') {|task, input| input += 5 }
  
    add_one.on_complete do |_result|
      # _result is the audit
      current_value = _result.value
  
      if current_value < 3 
        add_one.enq(_result)
      else
        add_five.enq(_result)
      end
    end
    
    add_one.enq(0)
    add_one.enq(1)
    add_one.enq(2)
  
    app.run
    assert_equal [8,8,8], app.results(add_five)

    target = StringIO.new("")
    app._results(add_five).each do |_result|
      target.puts "How #{_result._original} became #{_result.value}:"
      target.puts _result._to_s
      target.puts
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
o-[add_five] 8}.strip

    assert_equal expected, target.string.strip
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
    t = Task.intern(&add_one)
    t.enq 1
    app.run

    assert_audit_equal([[nil, 1], [t,2]], app._results(t).first)
    assert_equal [1], runlist
  end
  
  def test_run_executes_each_task_in_queue_in_order
    Task.intern(&echo).enq 1
    Task.intern(&echo).enq 2
    Task.intern(&echo).enq 3
    
    app.run

    assert_equal [[1],[2],[3]], runlist
  end
  
  def test_run_returns_self_when_running
    queue_before = nil
    queue_after = nil
    t1 = Task.intern do |task| 
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
  # run batched task tests
  #

  def test_run_batched_task
    t1 = Task.intern do |task, input|
      input = input + [task.batch_index]
      runlist << input
      input
    end
    t2 = t1.initialize_batch_obj

    t1.enq [0]
    app.run

    # the same input is fed to each batched task 
    assert_equal [
      [0,0],
      [0,1]
    ], runlist

    assert_audits_equal([
      [[nil,[0]],[t1,[0,0]]],
      [[nil,[0]],[t2,[0,1]]]
    ], app._results(*t1.batch))
  end
   
  def test_run_batched_task_with_existing_audit_trails
    t1 = Task.intern do |task, input|
      input = input + [task.batch_index]
      runlist << input
      input
    end
    t2 = t1.initialize_batch_obj

    a = Support::Audit.new(:a, [0])
    t1.enq a
    app.run

    # the same input is fed to each batched task 
    assert_equal [
      [0,0],
      [0,1]
    ], runlist

    assert_audits_equal([
      [[:a,[0]],[t1,[0,0]]],
      [[:a,[0]],[t2,[0,1]]]
    ], app._results(t1.batch))
  end
  
  #
  # _results test
  #

  def test__results_returns_audited_results_for_listed_sources
    a1 = Tap::Support::Audit.new(:t1, 1)
    a2 = Tap::Support::Audit.new(:t2, 2)
    
    app.aggregator.store a1
    app.aggregator.store a2
    assert_equal [a1], app._results(:t1)
    assert_equal [a2, a1], app._results(:t2, :t1)
    assert_equal [a1, a1], app._results(:t1, :t1)
  end
  
  #
  # results test
  #
  
  def test_results_documentation
    t0 = Task.intern  {|task, input| "#{input}.0" }
    t1 = Task.intern  {|task, input| "#{input}.1" }
    t2 = Task.intern  {|task, input| "#{input}.2" }
    t1.batch_with(t2)
  
    t0.enq(0)
    t1.enq(1)
  
    app.run
    assert_equal ["0.0", "1.1", "1.2"], app.results(t0, t1.batch)
    assert_equal ["1.1", "0.0"], app.results(t1, t0)
  end
  
  def test_results_returns_current_values_of__results
    a1 = Tap::Support::Audit.new(:t1, 1)
    a2 = Tap::Support::Audit.new(:t2, 2)
    
    app.aggregator.store a1
    app.aggregator.store a2
    assert_equal [1], app.results(:t1)
    assert_equal [2, 1], app.results(:t2, :t1)
    assert_equal [1, 1], app.results(:t1, :t1)
  end
  
  def test_results_for_various_objects
    t1 = Task.intern {|task, input| input}

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
    task = Task.intern {|t| raise "error"}
     
    string = set_stringio_logger
    task.enq
    app.run
    
    assert string =~ /RuntimeError error/
  end
  
  def test_terminate_errors_are_ignored
    was_in_block = false
    task = Task.intern do |t| 
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
