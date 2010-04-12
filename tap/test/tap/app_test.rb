require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/app'

class AppTest < Test::Unit::TestCase
  acts_as_file_test
  acts_as_subset_test
  App = Tap::App
  Env = Tap::Test::Env
  
  attr_reader :app
    
  def setup
    super
    @app = Tap::App.new({:debug => true}, {:env => Env.new})
    @context = App.set_context(Tap::App::CURRENT => @app)
  end
  
  def teardown
    App.set_context(@context)
    super
  end
  
  def default_config
    hash = {}
    App.configurations.each {|key, config| hash[key.to_s] = config.default }
    hash
  end
  
  #
  # OBJECT test
  #
  
  def test_OBJECT_regexp
    r = App::OBJECT
    
    assert 'nest/obj/sig' =~ r
    assert_equal 'nest/obj', $1
    assert_equal 'sig', $2
    
    assert 'obj/sig' =~ r
    assert_equal 'obj', $1
    assert_equal 'sig', $2
    
    assert '/sig' =~ r
    assert_equal '', $1
    assert_equal 'sig', $2
    
    assert '/' =~ r
    assert_equal '', $1
    assert_equal '', $2
    
    # non-matching
    assert 'str' !~ r
  end
   
  #
  # build test
  #
  
  def test_build_initializes_new_app_with_same_env_as_current
    instance = App.build
    assert_equal App, instance.class
    assert_equal false, instance.equal?(app)
    assert_equal app.env, instance.env
  end
  
  def test_build_builds_on_app_if_self_is_true
    assert_equal false, app.verbose
    
    instance = App.build({'config' => {'verbose' => true}, 'self' => true}, app)
    assert_equal true, instance.equal?(app)
    
    assert_equal true, app.verbose
  end
  
  def test_build_sets_config_and_builds_signals
    instance = App.build(
      'config' => {'verbose' => true},
      'signals' => [{'sig' => 'set', 'var' => 'app', 'class' => 'Tap::App', 'self' => 'true'}]
    )
    
    assert_equal true, instance.verbose
    assert_equal({'app' => instance}, instance.objects)
  end
  
  def test_build_collects_garbage
    instance = App.build(
      'config' => {'verbose' => true},
      'signals' => [
        {'sig' => 'set', 'var' => 'a', 'class' => 'Tap::App', 'self' => 'true'},
        {'sig' => 'set', 'var' => 'b', 'class' => 'Tap::App', 'self' => 'true'},
        {'sig' => 'set', 'var' => 1, 'class' => 'Tap::App', 'self' => 'true'},
        {'sig' => 'set', 'var' => 2, 'class' => 'Tap::App', 'self' => 'true'}
      ]
    )
    
    assert_equal({'a' => instance, 'b' => instance}, instance.objects)
  end
  
  # 
  # initialization tests
  #
  
  def test_default_app
    app = App.new

    assert_equal App::Queue, app.queue.class
    assert_equal 0, app.queue.size
    assert_equal App::Stack, app.stack.class
    assert_equal({}, app.objects)
    assert_equal App::State::READY, app.state
    assert_equal Tap::Env, app.env.class
  end
  
  #
  # log test
  #
  
  class LoggerClass
    attr_accessor :logs, :level
    def initialize
      @logs = []
    end
    def add(*args)
      logs << args
    end
  end
  
  def test_log_logs_to_log_device
    logger = LoggerClass.new
    app.logger = logger
    app.log(:action, "message")
    
    assert_equal [[Logger::INFO, "message", "action"]], logger.logs
  end
  
  def test_log_does_not_log_if_quiet
    logger = LoggerClass.new
    app.logger = logger
    app.quiet = true
    
    app.log(:action, "message")
    
    assert_equal [], logger.logs
  end
  
  def test_log_forces_log_if_verbose
    logger = LoggerClass.new
    app.logger = logger
    app.quiet = true
    app.verbose = true
    
    app.log(:action, "message")
    assert_equal [[Logger::INFO, "message", "action"]], logger.logs
  end
  
  def test_log_calls_block_for_message_if_unspecified
    logger = LoggerClass.new
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
    logger = LoggerClass.new
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
  # enq test
  #
  
  def test_enq_pushes_node_onto_queue
    n = lambda {}
    assert_equal 0, app.queue.size
    app.enq(n, :a)
    app.enq(n, :b)
    assert_equal [[n, :a], [n, :b]], app.queue.to_a
  end
  
  def test_enq_returns_enqued_node
    n = lambda {}
    assert_equal n, app.enq(n, :a)
  end
  
  #
  # pq test
  #
  
  def test_pq_unshifts_node_onto_queue
    n = lambda {}
    assert_equal 0, app.queue.size
    app.pq(n, :a)
    app.pq(n, :b)
    assert_equal [[n, :b], [n, :a]], app.queue.to_a
  end
  
  def test_pq_returns_enqued_node
    n = lambda {}
    assert_equal n, app.pq(n, :a)
  end
  
  #
  # set test
  #
  
  def test_set_sets_obj_into_objects_by_var
    assert app.objects.empty?
    
    obj = Object.new
    app.set('var', obj)
    assert_equal obj, app.objects['var']
  end
  
  def test_set_deletes_var_on_nil_obj
    obj = Object.new
    app.objects['var'] = obj
    assert_equal obj, app.set('var', nil)
    assert_equal false, app.objects.has_key?('var')
  end
  
  def test_set_returns_obj
    obj = Object.new
    assert_equal obj, app.set('var', obj)
  end
  
  #
  # get test
  #
  
  def test_get_returns_object_in_objects_keyed_by_var
    obj = Object.new
    app.objects['var'] = obj 
    assert_equal obj, app.get('var')
  end
  
  #
  # var test
  #
  
  def test_var_returns_key_for_obj_in_objects
    obj = Object.new
    app.objects['var'] = obj
    assert_equal 'var', app.var(obj)
  end
  
  def test_var_auto_assigns_a_variable_when_specified
    assert app.objects.empty?
    
    obj = Object.new
    assert_equal nil, app.var(obj, false)
    
    var = app.var(obj, true)
    assert !var.nil?
    assert_equal obj, app.objects[var]
  end
  
  #
  # call test
  #

  class SignalClass
    include Tap::Signals
    
    signal :echo
    
    def echo(*args)
      args << "echo"
      args
    end
  end

  def test_call_signals_object_with_args
    obj = SignalClass.new
    app.set('var', obj)
    
    assert_equal ["echo"], app.call(
      "obj" => "var", 
      "sig" => "echo", 
      "args" => []
    )
    
    assert_equal ["a", "b", "c", "echo"], app.call(
      "obj" => "var", 
      "sig" => "echo", 
      "args" => ["a", "b", "c"]
    )
  end
  
  def test_call_raises_error_for_unknown_object
    err = assert_raises(RuntimeError) { app.call('obj' => 'missing') }
    assert_equal "unknown object: \"missing\"", err.message
  end
  
  def test_call_raises_error_for_object_that_does_not_receive_signals
    obj = Object.new
    app.set('var', obj)
    
    err = assert_raises(RuntimeError) { app.call('obj' => 'var') }
    assert_equal "cannot signal: #{obj.inspect}", err.message
  end
  
  #
  # init test
  #
  
  class InitClass
    attr_reader :args
    attr_reader :block
    def initialize(*args, &block)
      @args = args
      @block = block
    end
  end
  
  def test_init_resolves_constant_and_initializes_with_args
    block = lambda {}
    obj = app.init('AppTest::InitClass', 1, 2, 3, &block)
    
    assert_equal InitClass, obj.class
    assert_equal [1, 2, 3], obj.args
    assert_equal block, obj.block
  end
  
  #
  # use test
  #
  
  class MiddlewareClass
    attr_reader :stack
    def initialize(stack)
      @stack = stack
    end
  end
  
  def test_use_initializes_middleware_with_stack_and_sets_result_as_stack
    stack = app.stack
    
    app.use MiddlewareClass
    assert_equal MiddlewareClass, app.stack.class
    assert_equal stack, app.stack.stack
    
    new_stack = app.stack
    
    app.use MiddlewareClass
    assert_equal MiddlewareClass, app.stack.class
    assert_equal new_stack, app.stack.stack
    assert_equal stack, app.stack.stack.stack
  end
  
  #
  # middleware test
  #
  
  def test_middleware_returns_an_array_of_middleware_in_use_by_self
    a = app.use MiddlewareClass
    b = app.use MiddlewareClass
    
    assert_equal [b,a], app.middleware
  end
  
  class StackSubclass < App::Stack
    def stack; app; end
  end
  
  def test_middleware_allows_subclasses_of_stack_as_middleware
    a = app.use MiddlewareClass
    b = app.use StackSubclass
    
    assert_equal [b,a], app.middleware
  end
  
  def test_middleware_returns_an_empty_array_if_no_middleware_is_in_use
    assert_equal [], app.middleware
  end
  
  #
  # reset test
  #
  
  def test_reset_clears_objects_queue_and_middleware
    app.objects['key'] = Object.new
    app.queue.enq(:node, :input)
    app.use MiddlewareClass
    
    assert_equal 1, app.objects.size
    assert_equal 1, app.queue.size
    assert_equal 1, app.middleware.size
    
    app.reset
    
    assert_equal 0, app.objects.size
    assert_equal 0, app.queue.size
    assert_equal 0, app.middleware.size
  end
  
  def test_reset_preserves_original_stack
    app = App.new
    stack = app.stack
     
    middleware = app.use MiddlewareClass
    assert_equal middleware, app.stack
    assert stack != middleware
    
    app.reset
    assert_equal stack, app.stack
  end
  
  #
  # exe test
  #
  
  def test_exe_calls_node_with_input
    was_in_block = false
    n = lambda do |input|
      assert_equal :input, input
      was_in_block = true
    end
    
    assert !was_in_block
    app.exe(n, :input)
    assert was_in_block
  end
  
  def test_default_exe_input_is_an_empty_array
    was_in_block = false
    n = lambda do |input|
      assert_equal [], input
      was_in_block = true
    end
    
    app.exe(n)
    assert was_in_block
  end
  
  def test_exe_returns_node_result
    n = lambda {|input| "result" }
    assert_equal "result", app.exe(n)
  end
  
  class NodeClass
    attr_accessor :joins
    def initialize(&block)
      @callable = block
      @joins = []
    end
    def call(input)
      @callable.call(input)
    end
  end
  
  def test_exe_calls_joins_if_specified
    n = NodeClass.new {|input| "result" }
    
    was_in_block_a = false
    join_a = lambda do |result|
      assert_equal "result", result
      was_in_block_a = true
    end
    
    was_in_block_b = false
    join_b = lambda do |result|
      assert_equal "result", result
      was_in_block_b = true
    end
    
    n.joins << join_a
    n.joins << join_b
    
    app.exe(n)
    assert was_in_block_a
    assert was_in_block_b
  end
  
  #
  # run tests
  #
  
  def test_run_calls_each_enqued_node_in_order
    runlist = []
    a = lambda {|input| input << 'a' } 
    b = lambda {|input| input << 'b' } 
    c = lambda {|input| input << 'c' } 
    
    app.enq a, runlist
    app.enq b, runlist
    app.enq c, runlist
    app.run
  
    assert_equal ['a', 'b', 'c'], runlist
  end
  
  def test_run_returns_immediately_when_already_running
    was_in_block = false
    
    n0 = lambda do |input| end
    n1 = lambda do |input|
      assert_equal [[n0, []]], app.queue.to_a
      app.run
      assert_equal [[n0, []]], app.queue.to_a
      was_in_block = true
    end
    
    app.enq n1
    app.enq n0
    app.run
    
    assert_equal true, was_in_block
  end
  
  def test_run_resets_state_to_ready
    in_block_state = nil
    n = lambda {|input| in_block_state = app.state }
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.enq n
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::RUN, in_block_state
  end
  
  def test_run_resets_state_to_ready_when_stopped
    in_block_state = nil
    n = lambda {|input| app.stop; in_block_state = app.state }
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.enq n
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::STOP, in_block_state
  end
  
  def test_run_resets_state_to_ready_when_terminated
    in_block_state = nil
    n = lambda do |input|
      app.terminate
      in_block_state = app.state
      
      app.check_terminate
      flunk "should have been terminated"
    end
    
    assert_equal App::State::READY, app.state
    assert_equal nil, in_block_state
    
    app.enq n
    app.run
    
    assert_equal App::State::READY, app.state
    assert_equal App::State::TERMINATE, in_block_state
  end
  
  def test_run_resets_state_to_ready_after_unhandled_error
    was_in_block = false
    n = lambda do |input|
      was_in_block = true
      raise "error!"
    end
    
    assert_equal App::State::READY, app.state
    assert_equal false, was_in_block
    
    app.enq n
    err = assert_raises(RuntimeError) { app.run }
    assert_equal "error!", err.message
    
    assert_equal App::State::READY, app.state
    assert_equal true, was_in_block
  end
  
  def test_run_returns_self
    assert_equal app, app.run
  end
  
  #
  # check_terminate tests
  #
  
  def test_check_terminate_yields_to_block_before_raising_terminiate_error
    was_in_block = false
    n = lambda do |input|
      app.terminate
      app.check_terminate { was_in_block = true }
      flunk "should have been terminated"
    end
    
    assert_equal false, was_in_block
    
    app.enq n
    app.run
    
    assert_equal true, was_in_block
  end
  
  #
  # info tests
  #
  
  def test_info_documentation
    assert_equal 'state: 0 (READY) queue: 0', App.new.info
  end
  
  #
  # serialize test
  #
  
  class AppObjectClass
    class << self
      def build(spec, app)
        new(spec['config'], app, spec['refs'], spec['brefs'])
      end
    end
    
    attr_reader :config
    attr_reader :associations
    
    def initialize(config={}, app=Tap::App.current, refs=nil, brefs=nil)
      @config = config
      @app = app
      @associations = [refs, brefs]
    end
    
    def to_spec
      refs, brefs = associations
      spec = {}
      spec['config'] = @config
      spec['refs']   = refs.collect  {|ref| @app.var(ref) } if refs
      spec['brefs']  = brefs.collect {|ref| @app.var(ref) } if brefs
      spec
    end
  end
  
  class AppObjectMiddleware
    class << self
      def build(spec, app)
        new(app.stack, spec['config'])
      end
    end
    
    attr_reader :stack
    attr_reader :config
    attr_reader :associations
    
    def initialize(stack, config={})
      @stack = stack
      @config = config
      @associations = nil
    end
    
    def to_spec
      {'config' => @config}
    end
  end
  
  def test_serialize_serializes_application_objects_into_signal
    app.set('var', AppObjectClass.new)
    
    assert_equal [
      { 'sig' => 'set',
        'var' => 'var', 
        'class' => 'AppTest::AppObjectClass', 
        'config' => {}
      }
    ], app.serialize
  end
  
  def test_serialize_orders_objects_by_var
    letters = ('a'..'z').to_a
    letters.each {|letter| app.set(letter, AppObjectClass.new)}
    
    order = app.serialize.collect {|hash| hash['var'] }
    assert_equal letters, order 
  end
  
  def test_serialize_orders_objects_by_associations
    a = AppObjectClass.new({'key' => 'a'}, app)
    b = AppObjectClass.new({'key' => 'b'}, app, [a])
    c = AppObjectClass.new({'key' => 'c'}, app)
    d = AppObjectClass.new({'key' => 'd'}, app, [b], [c])
    
    app.set('d', d)
    
    order = app.serialize.collect {|hash| hash['config']['key'] }
    assert_equal ['a', 'b', 'd', 'c'], order
  end
  
  def test_serialize_serializes_queue_into_signals
    obj = AppObjectClass.new
    app.set('var', obj)
    app.enq(obj, :input)
    
    assert_equal [
      { 'sig' => 'set',
        'var' => 'var', 
        'class' => 'AppTest::AppObjectClass', 
        'config' => {}
      },
      { 'sig' => 'enq', 
        'args' => {'var' => 'var', 'input' => :input}
      }
    ], app.serialize
  end
  
  def test_serialize_serializes_middleware_into_signals
    app.use AppObjectMiddleware, 'key' => 'value'
    
    assert_equal [
      { 'sig' => 'use',
        'class' => 'AppTest::AppObjectMiddleware', 
        'config' => {'key' => 'value'}
      }
    ], app.serialize
  end
  
  def test_serialize_sets_objects_if_necessary
    a = AppObjectClass.new({'key' => 'a'}, app)
    b = AppObjectClass.new({'key' => 'b'}, app, [a])
    
    app.enq(b, :input)
    
    assert_equal [
      { 'sig' => 'set',
        'var' => 1, 
        'class' => 'AppTest::AppObjectClass', 
        'config' => {'key' => 'a'}
      },
      { 'sig' => 'set',
        'var' => 0, 
        'class' => 'AppTest::AppObjectClass', 
        'refs' => [1],
        'config' => {'key' => 'b'}
      },
      { 'sig' => 'enq', 
        'args' => {'var' => 0, 'input' => :input}
      }
    ], app.serialize
  end

  def test_serialize_serializes_apps
    app_a = App.new :verbose => true
    a = AppObjectClass.new({}, app_a)
    app_a.set('a', a)
    
    app_b = App.new :quiet => true
    app_b.set('a', app_a)
    app_b.set('b', app_b)
    
    expected = [
      { 'sig' => 'set',
        'var' => 'b',
        'class' => 'Tap::App',
        'config' => default_config.merge('quiet' => true),
        'self' => true
      },
      { 'sig' => 'set',
        'var' => 'a', 
        'class' => 'Tap::App',
        'config' => default_config.merge('verbose' => true),
        'signals' => [
          { 'sig' => 'set',
            'var' => 'a', 
            'class' => 'AppTest::AppObjectClass', 
            'config' => {}
          }]
      }
    ]
    
    assert_equal expected, app_b.serialize(false)
  end

  #
  # to_spec test
  #
  
  def test_to_spec_converts_apps_to_spec
    app.set('var', AppObjectClass.new)
    
    assert_equal({
      'config' => default_config.merge('debug' => true),
      'signals' => [
        { 'sig' => 'set',
          'var' => 'var', 
          'class' => 'AppTest::AppObjectClass', 
          'config' => {}
        }
      ]
    }, app.to_spec)
  end
  
  def test_to_spec_build_rebuilds_app
    obj = AppObjectClass.new 'key' => 'obj'
    app.enq(obj, :input)
    app.use AppObjectMiddleware, 'key' => 'middleware'
    app.set('var', app)
    
    rebuilt = App.build(app.to_spec)
    
    assert_equal 1, rebuilt.queue.size
    obj, input = rebuilt.queue.deq
    
    assert_equal AppObjectClass, obj.class
    assert_equal({'key' => 'obj'}, obj.config)
    assert_equal :input, input
    
    assert_equal 1, rebuilt.middleware.size
    middleware = rebuilt.middleware[0]
    
    assert_equal AppObjectMiddleware, middleware.class
    assert_equal({'key' => 'middleware'}, middleware.config)
    
    assert_equal({'var' => rebuilt}, rebuilt.objects)
  end
  
  #
  # error tests
  #
  
  def test_terminate_errors_are_handled
    was_in_block = false
    n = lambda do |input|
      was_in_block = true
      raise Tap::App::TerminateError
      flunk "should have been terminated"
    end
    
    app.enq n
    app.run
    assert was_in_block
  end
  
  def test_terminate_errors_reque_the_latest_node
    was_in_block = false
    terminate = true
    n0 = lambda do |input|
      was_in_block = true
      raise Tap::App::TerminateError if terminate
    end
    n1 = lambda do |input| end
    
    app.enq n0, [1,2,3]
    app.enq n1
    
    assert_equal [[n0, [1,2,3]], [n1, []]], app.queue.to_a
    
    app.run
    assert was_in_block
    assert_equal [[n0, [1,2,3]], [n1, []]], app.queue.to_a
    
    terminate = false
    app.run
    assert_equal [], app.queue.to_a
  end
end
