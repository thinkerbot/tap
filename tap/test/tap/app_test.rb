require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'stringio'

class AppTest < Test::Unit::TestCase
  include Tap
  
  attr_reader :app, :runlist, :results
    
  def setup
    @results = []
    @app = Tap::App.new(:quiet => true) do |audit|
      result = audit.trail do |audit|
        [audit.key, audit.value]
      end
      @results << result
    end
    
    Tap::App.instance = @app
    @runlist = []
  end
  
  def teardown
    Tap::App.instance = nil
  end
  
  def intern(&block)
    App::Executable.initialize(block, :call, app)
  end
  
  # returns a tracing executable. tracer adds the key to 
  # runlist then returns input + key
  def tracer(key)
    intern do |input| 
      @runlist << key
      input += key
    end
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
    app = App.instance
  
    t = Task.intern {|task, *inputs| inputs }
    t.enq('a', 'b', 'c')
    t.enq(1)
    t.enq(2)
    t.enq(3)
  
    app.run
    assert_equal [['a', 'b', 'c'], [1], [2], [3]], app.results(t)
  
    ###
  
    t0 = Task.intern {|task| "0" }
    t1 = Task.intern {|task, input| "#{input}:1" }
    t2 = Task.intern {|task, input| "#{input}:2"}
  
    t0.on_complete {|_result| t1.enq(_result) }
    t1.on_complete {|_result| t2.enq(_result) }
    
    t0.enq
    app.run
    assert_equal [], app.results(t0, t1)
    assert_equal ["0:1:2"], app.results(t2)
  
    ###
  
    t2.enq("a")
    t1.enq("b")
    app.run
    assert_equal ["0:1:2", "a:2", "b:1:2"], app.results(t2)
  
    t0.name = "zero"
    t1.name = "one"
    t2.name = "two"
  
    trails = app._results(t2).collect do |_result|
      _result.dump
    end
  
    expected = %q{
o-[zero] "0"
o-[one] "0:1"
o-[two] "0:1:2"

o-[] "a"
o-[two] "a:2"

o-[] "b"
o-[one] "b:1"
o-[two] "b:1:2"
}
    assert_equal expected, "\n" + trails.join("\n")
  
    ###
    
    runlist = []
    t0 = Task.intern {|task| runlist << task }
    t1 = Task.intern {|task| runlist << task }
  
    t0.depends_on(t1)
    t0.enq
  
    app.run
    assert_equal [t1, t0], runlist
  
    ###
  
    t0.enq
    app.run
    assert_equal [t1, t0, t0], runlist
  
    ###
  
    array = []
  
    m = array._method(:push)
    m.enq(1)
    m.enq(2)
    m.enq(3)
  
    assert_equal true, array.empty?
    app.run
    assert_equal [1, 2, 3], array
  end
  
  def test_old_app_documentation
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

    expected = %Q{
o-[] 2
o-[add_one] 3
o-[add_five] 8
 
o-[] 1
o-[add_one] 2
o-[add_one] 3
o-[add_five] 8
 
o-[] 0
o-[add_one] 1
o-[add_one] 2
o-[add_one] 3
o-[add_five] 8
}

    assert_equal expected, "\n" + Tap::Support::Audit.dump(app._results(add_five), "")
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

    assert_equal(App::ExecutableQueue, app.queue.class)
    assert app.queue.empty?
    
    assert_equal(App::Aggregator, app.aggregator.class)
    assert app.aggregator.empty?
    
    assert_equal App::State::READY, app.state
  end
  
  def test_initialization_with_block_sets_aggregator
    b = lambda {}
    app = App.new(&b)
    assert_equal b, app.aggregator
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
  # run tests
  #

  def test_run_single_executable
    t = tracer('a')
    t.enq ''
    app.run
    
    assert_equal 1, results.length
    assert_equal [
      [nil, ''], 
      [t, 'a']
    ], results[0]
    
    assert_equal ['a'], runlist
  end
  
  def test_run_executes_each_task_in_queue_in_order
    tracer('a').enq ''
    tracer('b').enq ''
    tracer('c').enq ''
    
    app.run
  
    assert_equal ['a', 'b', 'c'], runlist
  end
  
  def test_run_returns_immediately_when_already_running
    queue_before = nil
    queue_after = nil
    t1 = intern do 
      queue_before = app.queue.to_a
      app.run
      queue_after = app.queue.to_a
    end
    t2 = intern {}
    
    t1.enq
    t2.enq
    app.run
    
    assert_equal [[t2, []]], queue_before
    assert_equal [[t2, []]], queue_after
  end
  
  def test_run_resets_state_to_ready
    in_block_state = nil
    intern { in_block_state = app.state }.enq
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::RUN, in_block_state
  end
  
  def test_run_resets_state_to_ready_when_stopped
    in_block_state = nil
    intern do
      app.stop
      in_block_state = app.state
    end.enq
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::STOP, in_block_state
  end
  
  def test_run_resets_state_to_ready_when_terminated
    in_block_state = nil
    t = intern do
      app.terminate
      in_block_state = app.state
      
      t.check_terminate
      flunk "should have been terminated"
    end
    t.enq
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::TERMINATE, in_block_state
  end
  
  def test_run_resets_state_to_ready_after_unhandled_error
    was_in_block = false
    intern do
      was_in_block = true
      raise "error!"
    end.enq
    
    assert_equal App::State::READY, app.state
    assert_equal false, was_in_block
    
    app.debug = true
    err = assert_raises(RuntimeError) { app.run }
    assert_equal "error!", err.message
    
    assert_equal App::State::READY, app.state
    assert_equal true, was_in_block
  end
  
  def test_run_returns_self
    assert_equal app, app.run
  end

  #
  # info tests
  #
  
  def test_info_provides_information_string
    assert_equal 'state: 0 (READY) queue: 0', app.info
  end

  #
  # enq test
  #
  
  def test_enq
    t = intern {}
    assert app.queue.empty?
    app.enq(t)
    assert_equal [[t, []]], app.queue.to_a
  end
  
  def test_enq_raises_error_if_input_is_not_an_Executable
    e = assert_raises(ArgumentError) { app.enq(:not_an_executable) }
    assert_equal "not an Executable: :not_an_executable", e.message
  end
  
  def test_enq_raises_error_task_is_not_assigned_to_app
    another = App.new
    t = intern {}
    
    assert t.app != another
    e = assert_raises(ArgumentError) { another.enq(t) }
    assert_equal "not assigned to enqueing app: #{t.inspect}", e.message
  end
  
  def test_enq_returns_enqued_task
    t = intern {}
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
  # on_complete test
  #
  
  def test_on_complete_sets_on_aggregator_for_self
    app.aggregator = nil
    assert_equal nil, app.aggregator

    b = lambda {}
    app.on_complete(&b)
    
    assert_equal b, app.aggregator
  end
  
  def test_on_complete_returns_self
    assert_equal app, app.on_complete
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
    was_in_block = false
    t = intern do
      was_in_block = true
      raise "error"
    end
     
    string = set_stringio_logger
    t.enq
    
    app.quiet = false
    app.run
    
    assert was_in_block
    assert string =~ /RuntimeError error/
  end
  
  def test_terminate_errors_are_ignored
    was_in_block = false
    t = intern do
      was_in_block = true
      raise Tap::App::TerminateError
      flunk "should have been terminated"
    end
     
    t.enq
    app.run
    assert was_in_block
  end
end
