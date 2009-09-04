require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'stringio'

class AppTest < Test::Unit::TestCase
  include Tap
  
  attr_reader :app, :runlist, :results
    
  def setup
    @results = []
    @app = Tap::App.new(:debug => true) do |result|
      @results << result
      result
    end
    @runlist = []
  end
  
  def intern(&block)
    App::Node.intern(&block)
  end
  
  # returns a tracing executable. node adds the key to 
  # runlist then returns input + key
  def node(key)
    intern do |input| 
      @runlist << key
      input += key
    end
  end
  
  #
  # documentation test
  #
  
  class AuditMiddleware
    attr_reader :stack, :audit

    def initialize(stack)
      @stack = stack
      @audit = []
    end

    def call(node, inputs=[])
      audit << node
      stack.call(node, inputs)
    end
  end
  
  def test_app_documentation
    app = Tap::App.new
    n = app.node {|*inputs| inputs }
    app.enq(n, 'a', 'b', 'c')
    app.enq(n, 1)
    app.enq(n, 2)
    app.enq(n, 3)
  
    results = []
    app.on_complete {|result| results << result }
  
    app.run
    assert_equal [['a', 'b', 'c'], [1], [2], [3]], results
  
    ###
    
    n0 = app.node { "a" }
    n1 = app.node {|input| "#{input}.b" }
    n2 = app.node {|input| "#{input}.c"}
  
    n0.on_complete {|result| app.execute(n1, result) }
    n1.on_complete {|result| app.execute(n2, result) }
    app.enq(n0)
  
    results.clear
    app.run
    assert_equal ["a.b.c"], results
  
    ###
  
    auditor = app.use AuditMiddleware
  
    app.enq(n0)
    app.enq(n2, "x")
    app.enq(n1, "y")
  
    results.clear
    app.run
    assert_equal ["a.b.c", "x.c", "y.b.c"], results
                 
    expected = [
    n0, n1, n2, 
    n2,
    n1, n2
    ]
    assert_equal expected, auditor.audit
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

    assert_equal(App::Queue, app.queue.class)
    assert app.queue.empty?
    assert_equal(App::Stack, app.stack.class)
    assert_equal [], app.joins
    assert_equal({}, app.cache)
    assert_equal App::State::READY, app.state
  end
  
  def test_initialization_with_block_sets_a_default_join
    b = lambda {}
    app = App.new(&b)
    assert_equal [b], app.joins
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
  # log test
  #
  
  class MockLogger
    attr_accessor :logs, :level
    def initialize
      @logs = []
    end
    def add(*args)
      logs << args
    end
  end
  
  def test_log_logs_to_log_device
    logger = MockLogger.new
    app.logger = logger
    app.log(:action, "message")
    
    assert_equal [[Logger::INFO, "message", "action"]], logger.logs
  end
  
  def test_log_does_not_log_if_quiet
    logger = MockLogger.new
    app.logger = logger
    app.quiet = true
    
    app.log(:action, "message")
    
    assert_equal [], logger.logs
  end
  
  def test_log_forces_log_if_verbose
    logger = MockLogger.new
    app.logger = logger
    app.quiet = true
    app.verbose = true
    
    app.log(:action, "message")
    assert_equal [[Logger::INFO, "message", "action"]], logger.logs
  end
  
  def test_log_calls_block_for_message_if_unspecified
    logger = MockLogger.new
    app.logger = logger
    
    was_in_block = false
    app.log(:action) do
      was_in_block = true
      "message"
    end
    
    assert_equal true, was_in_block
    assert_equal [[Logger::INFO, "message", "action"]], logger.logs
  end
  
  def test_log_does_not_call_block_if_quiet
    logger = MockLogger.new
    app.logger = logger
    app.quiet = true
    
    was_in_block = false
    app.log(:action) do
      was_in_block = true
      "message"
    end
    
    assert_equal false, was_in_block
    assert_equal [], logger.logs
  end
  
  #
  # node test
  #
  
  def test_node_interns_node_with_block
    n = app.node {|input| input + " was provided" }
    assert n.kind_of?(App::Node)
    assert_equal "str was provided", n.call("str")
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
  
  def test_enq_returns_enqued_task
    t = intern {}
    assert_equal t, app.enq(t)
  end
  
  #
  # bq test
  #
  
  def test_bq
    assert app.queue.empty?
    t = app.bq(1,2,3) {|*args| args}
    t1 = app.bq { "result" }
    
    assert_equal "result", t1.call
    assert_equal [[t, [1,2,3]], [t1, []]], app.queue.to_a
  end
  
  #
  # use test
  #
  
  class Middleware
    attr_reader :stack
    def initialize(stack)
      @stack = stack
    end
  end
  
  def test_use_initializes_middleware_with_stack_and_sets_result_as_stack
    stack = app.stack
    
    app.use(Middleware)
    assert_equal Middleware, app.stack.class
    assert_equal stack, app.stack.stack
    
    new_stack = app.stack
    
    app.use(Middleware)
    assert_equal Middleware, app.stack.class
    assert_equal new_stack, app.stack.stack
    assert_equal stack, app.stack.stack.stack
  end
  
  #
  # set test
  #
  
  def test_set_sets_obj_into_cache_by_var
    assert app.cache.empty?
    
    obj = Object.new
    app.set('var', obj)
    assert_equal obj, app.cache['var']
  end
  
  def test_set_converts_var_to_string
    assert app.cache.empty?
    
    obj = Object.new
    app.set(:var, obj)
    assert_equal obj, app.cache['var']
  end
  
  def test_set_returns_obj
    obj = Object.new
    assert_equal obj, app.set('var', obj)
  end
  
  def test_set_does_not_set_obj_if_var_is_empty
    assert app.cache.empty?
    app.set('', Object.new)
    app.set(nil, Object.new)
    assert app.cache.empty?
  end
  
  #
  # obj test
  #
  
  def test_obj_returns_object_in_cache_keyed_by_var
    obj = Object.new
    app.cache['var'] = obj 
    assert_equal obj, app.obj('var')
  end
  
  def test_obj_converts_var_to_string
    obj = Object.new
    app.cache['var'] = obj
    assert_equal obj, app.obj(:var)
  end
  
  def test_obj_returns_self_for_empty_var
    assert app.cache.empty?
    assert_equal app, app.obj('')
    assert_equal app, app.obj(nil)
  end
  
  #
  # var test
  #
  
  def test_var_returns_key_for_obj_in_cache
    obj = Object.new
    app.cache['var'] = obj
    assert_equal 'var', app.var(obj)
  end
  
  def test_var_auto_assigns_a_variable_when_specified
    assert app.cache.empty?
    
    obj = Object.new
    assert_equal nil, app.var(obj)
    
    var = app.var(obj, true)
    assert !var.nil?
    assert_equal obj, app.cache[var]
  end
  
  #
  # build test
  #
  
  class BuildClass < Tap::App::Api
    def self.minikey; "klass"; end
    config :key, 'value'
  end
  
  def test_build_instantiates_class_as_resolved_by_env
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build('class' => 'klass')
    assert_equal BuildClass, obj.class
    assert_equal 'value', obj.key
  end
  
  def test_build_raises_error_for_unresolvable_class
    app.env = {}
    err = assert_raises(RuntimeError) { app.build('type' => 'tipe', 'class' => 'klass') }
    assert_equal "unresolvable class: \"klass\"", err.message
  end
  
  def test_build_builds_class_using_args_if_specified
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'args' => {'config' => {'key' => 'alt'}})
    assert_equal 'alt', obj.key
  end
  
  def test_build_uses_spec_as_args_if_args_is_not_specified
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'config' => {'key' => 'alt'})
    assert_equal 'alt', obj.key
  end
  
  def test_build_parses_non_hash_args
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'args' => "--key alt")
    assert_equal 'alt', obj.key
  end
  
  def test_build_returns_remaining_args
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'args' => "a --key alt b c")
    assert_equal ["a", "b", "c"], args
  end
  
  def test_build_stores_obj_by_set_if_specified
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build('class' => 'klass')
    assert_equal({}, app.cache)
    
    obj, args = app.build('set' => 'variable', 'class' => 'klass')
    assert_equal({'variable' => obj}, app.cache)
  end

  #
  # middleware test
  #
  
  def test_middleware_returns_an_array_of_middleware_in_use_by_self
    a = app.use(Middleware)
    b = app.use(Middleware)
    
    assert_equal [b,a], app.middleware
  end
  
  def test_middleware_returns_an_empty_array_if_no_middleware_is_in_use
    assert_equal [], app.middleware
  end
  
  #
  # execute test
  #
  
  class ExecuteStack
    def initialize(stack)
      @stack = stack
    end
    
    def call(node, inputs)
      inputs << 'stack'
      @stack.call(node, inputs)
    end
  end
  
  def test_execute_calls_stack_with_node_and_inputs
    app.use ExecuteStack
    
    was_in_block = false
    n = intern do |*inputs|
      assert_equal [1,2,3,'stack'], inputs
      was_in_block = true
    end
    
    assert !was_in_block
    app.execute(n,1,2,3)
    assert was_in_block
  end
  
  #
  # dispatch test
  #
  
  def test_dispatch_calls_node_with_splat_inputs
    was_in_block = false
    n = intern do |*inputs|
      assert_equal [1,2,3], inputs
      was_in_block = true
    end
    
    assert !was_in_block
    app.dispatch(n, [1,2,3])
    assert was_in_block
  end
  
  def test_dispatch_returns_node_result
    n = intern { "result" }
    assert_equal "result", app.dispatch(n)
  end
  
  def test_dispatch_calls_joins_if_specified
    n = intern { "result" }
    
    was_in_block_a = false
    n.on_complete do |result|
      assert_equal "result", result
      was_in_block_a = true
    end
    
    was_in_block_b = false
    n.on_complete do |result|
      assert_equal "result", result
      was_in_block_b = true
    end
    
    app.dispatch(n)
    assert was_in_block_a
    assert was_in_block_b
  end
  
  def test_dispatch_calls_app_joins_if_no_joins_are_specified
    n = intern { "result" }
    
    was_in_block_a = false
    app.on_complete do |result|
      assert_equal "result", result
      was_in_block_a = true
    end
    
    was_in_block_b = false
    app.on_complete do |result|
      assert_equal "result", result
      was_in_block_b = true
    end
    
    app.dispatch(n)
    assert was_in_block_a
    assert was_in_block_b
  end
  
  class NilJoins
    def call
      "result"
    end
    def joins
      nil
    end
  end
  
  def test_dispatch_does_not_call_app_joins_if_joins_returns_nil
    n = NilJoins.new
    
    was_in_block = false
    app.on_complete do |result|
      assert_equal "result", result
      was_in_block = true
    end
    
    assert_equal "result", app.dispatch(n)
    assert_equal false, was_in_block
  end
  
  class NoJoins
    def call
      "result"
    end
  end
  
  def test_dispatch_does_not_call_app_joins_if_node_does_not_respond_to_joins
    n = NoJoins.new
    
    was_in_block = false
    app.on_complete do |result|
      assert_equal "result", result
      was_in_block = true
    end
    
    assert_equal "result", app.dispatch(n)
    assert_equal false, was_in_block
  end
  
  #
  # run tests
  #
  
  def test_simple_enque_and_run
    t = node('.b')
    app.enq t, 'a'
    app.run
    
    assert_equal 1, results.length
    assert_equal 'a.b', results[0]
    assert_equal ['.b'], runlist
  end
  
  def test_run_calls_each_node_in_order
    app.enq node('a'), ''
    app.enq node('b'), ''
    app.enq node('c'), ''
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
    
    app.enq t1
    app.enq t2
    app.run
    
    assert_equal [[t2, []]], queue_before
    assert_equal [[t2, []]], queue_after
  end
  
  def test_run_resets_state_to_ready
    in_block_state = nil
    app.bq { in_block_state = app.state }
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::RUN, in_block_state
  end
  
  def test_run_resets_state_to_ready_when_stopped
    in_block_state = nil
    app.bq intern do
      app.stop
      in_block_state = app.state
    end
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::STOP, in_block_state
  end
  
  def test_run_resets_state_to_ready_when_terminated
    in_block_state = nil
    app.bq intern do
      app.terminate
      in_block_state = app.state
      
      app.check_terminate
      flunk "should have been terminated"
    end
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::TERMINATE, in_block_state
  end
  
  def test_run_resets_state_to_ready_after_unhandled_error
    was_in_block = false
    app.bq do
      was_in_block = true
      raise "error!"
    end
    
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
  # on_complete test
  #
  
  def test_on_complete_sets_a_default_join_for_self
    app.joins.clear

    b = lambda {}
    app.on_complete(&b)
    
    assert_equal [b], app.joins
  end
  
  def test_on_complete_returns_self
    assert_equal app, app.on_complete
  end
  
  #
  # error tests
  #
  
  def test_terminate_errors_are_handled
    was_in_block = false
    app.bq do
      was_in_block = true
      raise Tap::App::TerminateError
      flunk "should have been terminated"
    end
    
    app.run
    assert was_in_block
  end
  
  def test_terminate_errors_reque_the_latest_node
    was_in_block = false
    terminate = true
    node = app.bq(1,2,3) do |*inputs|
      was_in_block = true
      raise Tap::App::TerminateError if terminate
    end
    another = app.bq {}
    
    assert_equal [[node, [1,2,3]], [another, []]], app.queue.to_a
    
    app.run
    assert was_in_block
    assert_equal [[node, [1,2,3]], [another, []]], app.queue.to_a
    
    terminate = false
    app.run
    assert_equal [], app.queue.to_a
  end
end
