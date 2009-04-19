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
    assert_equal App::STACK, app.stack
    assert_equal nil, app.default_join
    assert_equal({}, app.class_dependencies)
    assert_equal App::State::READY, app.state
  end
  
  def test_initialization_with_block_sets_default_join
    b = lambda {}
    app = App.new(&b)
    assert_equal b, app.default_join
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
  # class_dependency test
  #
  
  class ApplicationDependency
    def self.dependency(app)
      new(app)
    end
    
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
  end
  
  def test_class_dependency_returns_or_initializes_instance_of_class
    assert_equal({}, app.class_dependencies)
    d = app.class_dependency(ApplicationDependency)
    
    assert_equal ApplicationDependency, d.class
    assert App::Dependency.dependency?(d)
    assert_equal({ApplicationDependency.to_s => d}, app.class_dependencies)
    
    assert_equal d.object_id, app.class_dependency(ApplicationDependency).object_id
  end
  
  def test_initialized_instance_uses_app
    app = Tap::App.new
    d = app.class_dependency(ApplicationDependency)
    assert_equal app, d.app
  end
  
  #
  # dependency test
  #
  
  def test_dependency_interns_dependency_with_block
    d = app.dependency { "result" }
    assert App::Dependency.dependency?(d)
    
    assert_equal nil, d.result
    d.call
    assert_equal "result", d.result
  end
  
  #
  # node test
  #
  
  def test_node_interns_node_with_block
    n = app.node {|input| input + " was provided" }
    assert App::Node.node?(n)
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
    assert_equal App::STACK, app.stack
    
    app.use(Middleware)
    assert_equal Middleware, app.stack.class
    assert_equal App::STACK, app.stack.stack
    
    stack = app.stack
    
    app.use(Middleware)
    assert_equal Middleware, app.stack.class
    assert_equal stack, app.stack.stack
    assert_equal App::STACK, app.stack.stack.stack
  end
  
  #
  # resolve test
  #
  
  def test_resolve_recursively_resolves_dependencies_of_node
    n0 = intern {}
    n1 = intern { 1 }
    n2 = intern { 2 }
    
    n0.depends_on(n1)
    n1.depends_on(n2)
    
    assert_equal nil, n1.result
    assert_equal nil, n2.result
    
    app.resolve(n0)
    
    assert_equal 1, n1.result
    assert_equal 2, n2.result
  end
  
  def test_resolve_resolves_dependencies_only_once
    n0 = intern {}
    n1 = intern { runlist << 1 }
    n2 = intern { runlist << 2 }
    n3 = intern { runlist << 3 }
    
    n0.depends_on(n1)
    n0.depends_on(n2)
    n2.depends_on(n3)
    
    app.resolve(n0)
    assert_equal [1,3,2], runlist
    
    app.resolve(n0)
    assert_equal [1,3,2], runlist
  end
  
  def test_resolve_raises_error_for_circular_dependencies
    n0 = intern {}
    n1 = intern {}
    
    n0.depends_on(n1)
    n1.depends_on(n0)
    
    assert_raises(App::DependencyError) { app.resolve(n0) }
  end
  
  #
  # reset test
  #
  
  def test_reset_recursively_resets_dependencies_of_node
    n0 = intern {}
    n1 = intern { runlist << 1 }
    n2 = intern { runlist << 2 }
    n3 = intern { runlist << 3 }
    
    n0.depends_on(n1)
    n0.depends_on(n2)
    n2.depends_on(n3)
    
    app.resolve(n0)
    assert_equal [1,3,2], runlist
    
    app.reset(n0)
    app.resolve(n0)
    assert_equal [1,3,2,1,3,2], runlist
  end
  
  def test_reset_only_resets_dependencies_of_current_node_if_recursive_is_false
    n0 = intern {}
    n1 = intern { runlist << 1 }
    n2 = intern { runlist << 2 }
    n3 = intern { runlist << 3 }
    
    n0.depends_on(n1)
    n0.depends_on(n2)
    n2.depends_on(n3)
    
    app.resolve(n0)
    assert_equal [1,3,2], runlist
    
    app.reset(n0, false)
    app.resolve(n0)
    assert_equal [1,3,2,1,2], runlist
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
  
  def test_dispatch_calls_join_if_specified
    n = intern { "result" }
    
    was_in_block = false
    n.on_complete do |result|
      assert_equal "result", result
      was_in_block = true
    end
    
    app.dispatch(n)
    assert was_in_block
  end
  
  def test_dispatch_calls_default_join_if_no_join_is_specified
    n = intern { "result" }
    
    was_in_block = false
    app.on_complete do |result|
      assert_equal "result", result
      was_in_block = true
    end
    
    app.dispatch(n)
    assert was_in_block
  end
  
  def test_dispatch_resolves_dependencies_before_execution
    n1 = intern { runlist << 1 }
    n2 = intern { runlist << 2 }
    n3 = intern { runlist << 3 }
    
    n1.depends_on(n2)
    n2.depends_on(n3)
    
    app.dispatch(n1)
    assert_equal [3,2,1], runlist
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
  
  def test_on_complete_sets_the_default_join_for_self
    app.default_join = nil
    assert_equal nil, app.default_join

    b = lambda {}
    app.on_complete(&b)
    
    assert_equal b, app.default_join
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
  
  def test_unhandled_exception_is_logged_when_debug_is_false
    was_in_block = false
    app.bq do
      was_in_block = true
      raise "error"
    end
     
    string = set_stringio_logger
    app.debug = false
    app.run
    
    assert was_in_block
    assert string =~ /RuntimeError error/
  end
  
  def test_terminate_errors_are_ignored
    was_in_block = false
    app.bq do
      was_in_block = true
      raise Tap::App::TerminateError
      flunk "should have been terminated"
    end
    
    app.run
    assert was_in_block
  end
end
