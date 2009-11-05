require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'stringio'
require 'tap/test'

class AppTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test
  acts_as_subset_test
  
  App = Tap::App
  
  attr_reader :app, :runlist, :results
    
  def setup
    super
    
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
      audit << [node, inputs]
      stack.call(node, inputs)
    end
  end
  
  class Resource
    class << self
      def parse!(argv=ARGV, app=Tap::App.instance)
        build({'argv' => argv}, app)
      end

      def build(spec={}, app=Tap::App.instance)
        new(spec['argv'], app)
      end
    end

    attr_reader :argv, :app
    def initialize(argv, app)
      @argv = argv
      @app = app
    end

    def associations
      nil
    end

    def to_spec
      {'argv' => @argv}
    end
  end
  
  class Resource
    include Tap::Signals
    signal :length

    def length(extra=0)
      @argv.length + extra
    end
  end
  
  def test_app_documentation
    # implement a command line workflow in ruby
    # % cat [file] | sort
  
    app = Tap::App.new
    cat  = app.node {|file| File.read(file) }
    sort = app.node {|str| str.split("\n").sort }
    cat.on_complete {|res| app.enq(sort, res) }
  
    results = []
    app.on_complete {|result| results << result }
  
    example = method_root.prepare(:tmp, "example.txt") do |io|
      io.puts "a"
      io.puts "c"
      io.puts "b"
    end
  
    app.enq(cat, example)
    app.run
    assert_equal [["a", "b", "c"]], results
  
    rsort = app.node {|str| str.split("\n").sort.reverse }
    cat.on_complete  {|res| app.enq(rsort, res) }
    assert_equal 2, cat.joins.length
    
    results.clear
    app.enq(cat, example)
    app.run
    assert_equal [["a", "b", "c"], ["c", "b", "a"]], results
    
    ##
    
    auditor = app.use AuditMiddleware
  
    app.enq(cat, example)
    app.run
  
    expected = [
    [cat, [example]],
    [sort, ["a\nc\nb\n"]],
    [rsort, ["a\nc\nb\n"]]
    ]
    assert_equal expected, auditor.audit
  
    ##
    extended_test do
      runlist = []
      node = app.node { runlist << "node" }
      app.enq(node)
  
      assert_equal [], runlist
      assert_equal [[node, []]], app.queue.to_a
      assert_equal App::State::READY, app.state
  
      app.run
      assert_equal ["node"], runlist
      assert_equal [], app.queue.to_a
  
      sleeper = app.node { sleep 1; runlist << "sleeper" }
      app.enq(node)
      app.enq(sleeper)
      app.enq(node)
  
      runlist.clear
      assert_equal [[node, []], [sleeper, []], [node, []]], app.queue.to_a
  
      a = Thread.new { app.run }
      Thread.new do 
        Thread.pass while runlist.empty?
        app.stop
        a.join
      end.join
    
      assert_equal ["node", "sleeper"], runlist
      assert_equal [[node, []]], app.queue.to_a
    
      app.run
      assert_equal ["node", "sleeper", "node"], runlist
      assert_equal [], app.queue.to_a

      terminator = app.node do
        sleep 1
        app.check_terminate
        runlist << "terminator"
      end
      app.enq(node)
      app.enq(terminator)
      app.enq(node)
  
      runlist.clear
      assert_equal [[node, []], [terminator, []], [node, []]], app.queue.to_a
  
      a = Thread.new { app.run }
      Thread.new do 
        Thread.pass while runlist.empty?
        app.terminate
        a.join
      end.join
  
      assert_equal ["node"], runlist
      assert_equal [[terminator, []], [node, []]], app.queue.to_a
  
      app.run
      assert_equal ["node", "terminator", "node"], runlist
      assert_equal [], app.queue.to_a
    end
    
    app = App.new
    app.set('a', :A)
    assert_equal :A, app.get('a')
    assert_equal({'a' => :A}, app.objects)
  
    a = Resource.parse!([1, 2, 3], app)
    assert_equal [1, 2, 3], a.argv
  
    b = Resource.build(a.to_spec, app)
    assert_equal [1, 2, 3], b.argv
  
    app.build('var' => 'a', 'class' => 'AppTest::Resource', 'spec' => [1, 2, 3])
    a = app.get('a')
    assert_equal Resource, a.class
    assert_equal [1, 2, 3], a.argv
  
    app.build('var' => 'b', 'class' => 'AppTest::Resource', 'spec' => {'argv' => [4, 5, 6]})
    app.build('var' => 'c', 'class' => 'AppTest::Resource', 'argv' => [7, 8, 9])
    
    expected = [
    {'var' => 'a', 'class' => 'AppTest::Resource', 'argv' => [1, 2, 3]},
    {'var' => 'b', 'class' => 'AppTest::Resource', 'argv' => [4, 5, 6]},
    {'var' => 'c', 'class' => 'AppTest::Resource', 'argv' => [7, 8, 9]}
    ]
    assert_equal expected, app.to_schema
    
    ###
  
    app = App.new
    app.set('', app)
    app.call(
      'obj' => '', 
      'sig' => 'build', 
      'args' => {
        'var' => 'a',
        'class' => 'AppTest::Resource',
        'spec' => {'argv' => [1, 2, 3]}
       }
    )
    a = app.get('a')
    assert_equal Resource, a.class
    assert_equal [1, 2, 3], a.argv
  
    app.call('var' => 'b', 'class' => 'AppTest::Resource', 'argv' => [4, 5])
    b = app.get('b')
    assert_equal Resource, b.class
    assert_equal [4, 5], b.argv
  
    assert_equal 3, a.length
    assert_equal 2, b.length
    assert_equal 3, b.length(1)
  
    assert_equal 3, app.call('obj' => 'a', 'sig' => 'length', 'args' => [])
    assert_equal 2, app.call('obj' => 'b', 'sig' => 'length', 'args' => [])
    assert_equal 3, app.call('obj' => 'b', 'sig' => 'length', 'args' => [1])
  end
  
  class OldAuditMiddleware
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
  
  def test_old_app_documentation
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
  
    auditor = app.use OldAuditMiddleware
  
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
  # build test
  #
  
  def test_build_initializes_new_app
    instance = App.build
    assert_equal false, instance.equal?(app)
    assert_equal App, instance.class
    assert_equal({}, instance.objects)
  end
  
  def test_build_builds_on_app_if_self_is_true
    assert_equal false, app.verbose
    
    instance = App.build({'config' => {'verbose' => true}, 'self' => true}, app)
    assert_equal true, instance.equal?(app)
    
    assert_equal true, app.verbose
  end
  
  def test_build_sets_config_and_builds_schema
    instance = App.build(
      'config' => {'verbose' => true},
      'schema' => [{'var' => 'app', 'class' => 'Tap::App', 'self' => 'true'}]
    )
    assert_equal false, instance.equal?(app)
    assert_equal true, instance.verbose
    assert_equal({'app' => instance}, instance.objects)
  end
  
  def test_build_collects_garbage
    instance = App.build(
      'config' => {'verbose' => true},
      'schema' => [
        {'var' => 'a', 'class' => 'Tap::App', 'self' => 'true'},
        {'var' => 'b', 'class' => 'Tap::App', 'self' => 'true'},
        {'var' => 1, 'class' => 'Tap::App', 'self' => 'true'},
        {'var' => 2, 'class' => 'Tap::App', 'self' => 'true'}
      ]
    )
    
    assert_equal({'a' => instance, 'b' => instance}, instance.objects)
  end
  
  # 
  # initialization tests
  #
  
  def test_default_app
    app = App.new

    assert_equal(App::Queue, app.queue.class)
    assert_equal 0, app.queue.size
    assert_equal(App::Stack, app.stack.class)
    assert_equal [], app.joins
    assert_equal({}, app.objects)
    assert_equal App::State::READY, app.state
    assert_equal nil, app.env
  end
  
  def test_initialization_with_block_sets_a_default_join
    b = lambda {}
    app = App.new(&b)
    assert_equal [b], app.joins
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
    assert_equal 0, app.queue.size
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
    assert_equal 0, app.queue.size
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

  class AppObject < App::Api
    signal :echo
    
    def echo(*args)
      args << "echo"
      args
    end
  end

  def test_call_signals_object_with_args
    obj = AppObject.new
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
  
  def test_call_pre_processes_strings_into_args_hash
    obj = AppObject.new
    app.set('var', obj)
    
    assert_equal ["echo"], app.call("var/echo")
    assert_equal ["a", "b", "c", "echo"], app.call("var/echo a b c")
  end
  
  def test_call_pre_processes_arrays_into_args_hash
    obj = AppObject.new
    app.set('var', obj)
    
    assert_equal ["echo"], app.call(["var/echo"])
    assert_equal ["a", "b", "c", "echo"], app.call(["var/echo", "a", "b", "c"])
  end
  
  def test_call_interprets_obj_as_all_preceding_first_slash
    obj = AppObject.new
    app.set('a', obj)
    app.set('a/b', obj)
    
    assert_equal app.info, app.call("info")
    
    err = assert_raises(RuntimeError) { app.call("a") }
    assert_equal "unknown signal: a (Tap::App)", err.message
    
    assert_equal ["echo"], app.call("a/echo")
    assert_equal ["b", "c", "d", "echo"], app.call("a/echo b c d")
    
    assert_equal ["echo"], app.call("a/b/echo")
    assert_equal ["c", "d", "e", "echo"], app.call("a/b/echo c d e")
    
    err = assert_raises(RuntimeError) { app.call("a/b/c/echo") }
    assert_equal "unknown object: \"a/b/c\"", err.message
    
    err = assert_raises(RuntimeError) { app.call("/info") }
    assert_equal "unknown object: \"\"", err.message
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
    err = assert_raises(RuntimeError) { app.build('class' => 'klass') }
    assert_equal "unresolvable constant: \"klass\"", err.message
  end
  
  def test_build_builds_class_using_spec_if_specified
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'spec' => {'config' => {'key' => 'alt'}})
    assert_equal 'alt', obj.key
  end
  
  def test_build_uses_spec_as_spec_if_spec_is_not_specified
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'config' => {'key' => 'alt'})
    assert_equal 'alt', obj.key
  end
  
  def test_build_parses_non_hash_spec
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'spec' => "--key alt")
    assert_equal 'alt', obj.key
  end
  
  def test_build_returns_remaining_args
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build(
      'class' => 'klass',
      'spec' => "a --key alt b c")
    assert_equal ["a", "b", "c"], args
  end
  
  def test_build_stores_obj_by_var_if_specified
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build('class' => 'klass')
    assert_equal({}, app.objects)
    
    obj, args = app.build('var' => 'variable', 'class' => 'klass')
    assert_equal({'variable' => obj}, app.objects)
  end
  
  def test_build_stores_obj_by_multiple_var_if_specified
    app.env = {'klass' => BuildClass}
    
    obj, args = app.build('class' => 'klass')
    assert_equal({}, app.objects)
    
    obj, args = app.build('var' => ['a', 'b'], 'class' => 'klass')
    assert_equal({'a' => obj, 'b' => obj}, app.objects)
  end
  
  #
  # enque test
  #
  
  def test_enque_enques_the_specified_object_with_args
    obj = Object.new
    app.set('var', obj)
    
    assert_equal [], app.queue.to_a
    app.enque('var', 1,2,3)
    assert_equal [[obj, [1,2,3]]], app.queue.to_a
  end
  
  def test_enque_raises_error_when_specified_obj_does_not_exist
    err = assert_raises(RuntimeError) { app.enque('missing', 1,2,3) }
    assert_equal "unknown object: \"missing\"", err.message
  end
  
  #
  # middleware test
  #
  
  def test_middleware_returns_an_array_of_middleware_in_use_by_self
    a = app.use(Middleware)
    b = app.use(Middleware)
    
    assert_equal [b,a], app.middleware
  end
  
  class StackMiddleware < App::Stack
    def stack; app; end
  end
  
  def test_middleware_allows_subclasses_of_stack_as_middleware
    a = app.use(Middleware)
    b = app.use(StackMiddleware)
    
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
    app.use(Middleware)
    
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
     
    middleware = app.use(Middleware)
    assert_equal middleware, app.stack
    assert stack != middleware
    
    app.reset
    assert_equal stack, app.stack
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
  # check_terminate tests
  #
  
  def test_check_terminate_yields_to_block_before_raising_terminiate_error
    was_in_block = false
    app.bq intern do
      app.terminate
      app.check_terminate { was_in_block = true }
      flunk "should have been terminated"
    end
    
    assert_equal false, was_in_block
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
  # to_schema test
  #
  
  class SchemaObj < App::Api
    config :key, 'value'
    
    attr_accessor :associations
    
    def initialize(config={}, app=Tap::App.instance, refs=nil, brefs=nil)
      super(config, app)
      @associations = [refs, brefs]
    end
    
    def to_spec
      refs, brefs = associations
      spec = super
      spec['refs'] = refs.collect {|ref| app.var(ref) } if refs
      spec['brefs'] = brefs.collect {|ref| app.var(ref) } if brefs
      spec
    end
  end
  
  class SchemaMiddleware < App::Api
    class << self
      def build(spec={}, app=Tap::App.instance)
        app.use(self, spec['config'] || {})
      end
    end
    
    attr_reader :stack
    
    def initialize(stack, config={})
      @stack = stack
      initialize_config(config)
    end
    
    def call(node, inputs=[])
      inputs << "middleware"
      stack.call(node, inputs)
    end
  end
  
  def test_to_schema_serializes_application_objects=
    app.set('var', SchemaObj.new)
    
    assert_equal [
      { 'var' => 'var', 
        'class' => 'AppTest::SchemaObj', 
        'config' => {'key' => 'value'}
      }
    ], app.to_schema
  end
  
  def test_to_schema_serializes_queue
    obj = SchemaObj.new
    app.set('var', obj)
    app.enq(obj, 1, 2, 3)
    
    assert_equal [
      { 'var' => 'var', 
        'class' => 'AppTest::SchemaObj', 
        'config' => {'key' => 'value'}
      },
      { 'sig' => 'enque', 
        'args' => ['var', 1,2,3]
      }
    ], app.to_schema
  end
  
  def test_to_schema_adds_sets_objects_if_necessary
    app.enq(SchemaObj.new, 1, 2, 3)
    
    assert_equal [
      { 'var' => 0, 
        'class' => 'AppTest::SchemaObj', 
        'config' => {'key' => 'value'}
      },
      { 'sig' => 'enque', 
        'args' => [0, 1,2,3]
      }
    ], app.to_schema
  end
  
  def test_to_schema_orders_objects_by_var
    letters = ('a'..'z').to_a
    letters.each do |letter|
      app.set(letter, SchemaObj.new)
    end
    
    order = app.to_schema.collect {|hash| hash['var'] }
    assert_equal letters, order 
  end
  
  def test_to_schema_orders_objects_by_associations
    a = SchemaObj.new({:key => 'a'}, app)
    b = SchemaObj.new({:key => 'b'}, app, [a])
    c = SchemaObj.new({:key => 'c'}, app)
    d = SchemaObj.new({:key => 'd'}, app, [b], [c])
    
    app.set('d', d)
    
    assert_equal [
      { 'var' => 3, 
        'class' => 'AppTest::SchemaObj', 
        'config' => {'key' => 'a'}
      },
      { 'var' => 1, 
        'class' => 'AppTest::SchemaObj', 
        'config' => {'key' => 'b'},
        'refs' => [3]
      },
      { 'var' => 'd', 
        'class' => 'AppTest::SchemaObj', 
        'config' => {'key' => 'd'},
        'refs' => [1],
        'brefs' => [2]
      },
      { 'var' => 2, 
        'class' => 'AppTest::SchemaObj', 
        'config' => {'key' => 'c'}
      }
    ], app.to_schema
  end
  
  def test_to_schema_serializes_apps
    app_a = App.new :verbose => true
    a = SchemaObj.new({}, app_a)
    app_a.set('a', a)
    
    app_b = App.new :quiet => true
    app_b.set('a', app_a)
    app_b.set('b', app_b)
    
    expected = [
      { 'var' => 'b',
        'class' => 'Tap::App',
        'config' => {
          "quiet"=>true,
          "env"=>nil,
          "force"=>false,
          "verbose"=>false,
          "debug"=>false
        },
        'self' => true
      },
      { 'var' => 'a', 
        'class' => 'Tap::App',
        'config' => {
          "quiet"=>false,
          "env"=>nil,
          "force"=>false,
          "verbose"=>true,
          "debug"=>false
        },
        'schema' => [
          { 'var' => 'a', 
            'class' => 'AppTest::SchemaObj', 
            'config' => {'key' => 'value'}
          }]
      }
    ]
    
    assert_equal expected, app_b.to_schema(false)
  end
  
  class NestSchemaByVar
    def to_spec
      {'var' => 'this'}
    end
  end
  
  class NestSchemaByObj
    def to_spec
      {'obj' => 'this'}
    end
  end
  
  def test_to_schema_nests_build_hashes_if_necessary
    app.set('by_var', NestSchemaByVar.new)
    app.set('by_obj', NestSchemaByObj.new)
    
    assert_equal [
      { 
        'var' => 'by_obj', 
        'class' => 'AppTest::NestSchemaByObj',
        'spec' => {'obj' => 'this'}
      },
      { 
        'var' => 'by_var', 
        'class' => 'AppTest::NestSchemaByVar',
        'spec' => {'var' => 'this'}
      }
    ], app.to_schema
  end
  
  #
  # to_spec test
  #
  
  def test_to_spec_converts_apps_to_spec
    app_a = App.new :verbose => true
    a = SchemaObj.new({}, app_a)
    app_a.set('a', a)
    
    app_b = App.new :quiet => true
    app_b.set('a', app_a)
    app_b.set('b', app_b)
    
    expected = {
      'config' => {
        "quiet"=>true,
        "env"=>nil,
        "force"=>false,
        "verbose"=>false,
        "debug"=>false
      },
      'schema' => [
        {"self"=>true, "class"=>"Tap::App", "var"=>"b"},
        { 'var' => 'a', 
          'class' => 'Tap::App',
          'config' => {
            "quiet"=>false,
            "env"=>nil,
            "force"=>false,
            "verbose"=>true,
            "debug"=>false
          },
          'schema' => [
            { 'var' => 'a', 
              'class' => 'AppTest::SchemaObj', 
              'config' => {'key' => 'value'}
            }]}]
    }
    
    assert_equal expected, app_b.to_spec
  end
  
  def test_to_spec_build_rebuilds_app
    obj = SchemaObj.new :key => 'obj'
    app.use SchemaMiddleware
    app.enq(obj, 1,2,3)
    app.set('var', app)
    
    alt = App.build(app.to_spec)
    
    assert_equal [SchemaMiddleware], app.middleware.collect {|m| m.class }
    assert_equal 1, app.queue.size
    
    obj, args = app.queue.deq
    assert_equal 'obj', obj.config[:key]
    assert_equal [1,2,3], args
    assert_equal({'var' => alt}, alt.objects)
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
