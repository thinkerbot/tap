require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'tap/test'

class AppSignalsTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  App = Tap::App
  
  #
  # enq test
  #
  
  def test_enq_enques_obj_with_inputs
    n = app.node {}
    app.set(0, n)
    app.call('sig' => 'enq', 'args' => [0, 1,2,3])
    app.call('sig' => 'enq', 'args' => [0, 4,5,6])
    assert_equal [[n, [1,2,3]], [n, [4,5,6]]], app.queue.to_a
  end
  
  def test_enq_raises_error_for_unknown_obj
    err = assert_raises(RuntimeError) { app.call('sig' => 'enq', 'args' => [0]) }
    assert_equal "no object set to: 0", err.message
  end
  
  #
  # pq test
  #
  
  def test_pq_priority_enques_obj_with_inputs
    n = app.node {}
    app.set(0, n)
    app.call('sig' => 'pq', 'args' => [0, 1,2,3])
    app.call('sig' => 'pq', 'args' => [0, 4,5,6])
    assert_equal [[n, [4,5,6]], [n, [1,2,3]]], app.queue.to_a
  end
  
  def test_pq_raises_error_for_unknown_obj
    err = assert_raises(RuntimeError) { app.call('sig' => 'pq', 'args' => [0]) }
    assert_equal "no object set to: 0", err.message
  end
  
  #
  # set test
  #
  
  class SetClass < App::Api
    class << self
      def build(spec, app)
        obj = super
        obj.build_method = :build
        obj
      end
      
      def parse(argv, app)
        obj, args = super
        obj.build_method = :parse
        [obj, args]
      end
      
      def parse!(argv, app)
        obj, args = super
        obj.build_method = :parse!
        [obj, args]
      end
      
      def minikey
        "klass"
      end
    end
    
    config :key, 'value'
    attr_accessor :build_method
  end
  
  def test_set_instantiates_and_stores_obj_by_var
    app.env = {'klass' => SetClass}
    
    obj = app.call('sig' => 'set', 'args' => ['var', 'klass'])
    assert_equal SetClass, obj.class
    assert_equal({'var' => obj}, app.objects)
  end
  
  def test_set_does_not_set_obj_for_nil_var
    app.env = {'klass' => SetClass}
    
    obj = app.call('sig' => 'set', 'args' => [nil, 'klass'])
    assert_equal({}, app.objects)
  end
  
  def test_set_parse_bangs_remaining_args
    app.env = {'klass' => SetClass}
    
    was_in_block = false
    obj = app.call('sig' => 'set', 'args' => ['var', 'klass', 'a', 'b', 'c']) do |o, args|
      assert_equal ['a', 'b', 'c'], args
      was_in_block = true
    end
    
    assert_equal :parse!, obj.build_method
    assert_equal true, was_in_block
  end
  
  def test_set_parses_remaining_args_if_bang_is_false
    app.env = {'klass' => SetClass}
    
    app.bang = false
    was_in_block = false
    obj = app.call('sig' => 'set', 'args' => ['var', 'klass', 'a', 'b', 'c']) do |o, args|
      assert_equal ['a', 'b', 'c'], args
      was_in_block = true
    end
    
    assert_equal :parse, obj.build_method
    assert_equal true, was_in_block
  end
  
  def test_set_initializes_with_spec_if_specified
    app.env = {'klass' => SetClass}
    
    obj = app.call(
      'sig' => 'set',
      'class' => 'klass',
      'spec' => {'config' => {'key' => 'alt'}})
    assert_equal 'alt', obj.key
  end
  
  def test_set_builds_hash_spec
    app.env = {'klass' => SetClass}
    
    obj = app.call('sig' => 'set', 'class' => 'klass', 'spec' => {})
    assert_equal :build, obj.build_method
  end
  
  def test_set_stores_obj_by_multiple_var_if_specified
    app.env = {'klass' => SetClass}
    
    obj = app.call('sig' => 'set', 'class' => 'klass')
    assert_equal({}, app.objects)
    
    obj = app.call('sig' => 'set', 'var' => ['a', 'b'], 'class' => 'klass')
    assert_equal({'a' => obj, 'b' => obj}, app.objects)
  end
  
  def test_set_raises_error_for_unresolvable_class
    app.env = {}
    err = assert_raises(RuntimeError) { app.call('sig' => 'set', 'args' => ['var', 'klass']) }
    assert_equal "unresolvable constant: \"klass\"", err.message
  end
  
  #
  # get test
  #
  
  def test_get_returns_specified_object
    n = app.node {}
    app.set(0, n)
    assert_equal n,  app.call('sig' => 'get', 'args' => [0])
  end
  
  def test_get_returns_nil_for_missing_object
    assert_equal nil,  app.call('sig' => 'get', 'args' => [1])
  end
  
  #
  # resolve test
  #
  
  def test_resolve_resolves_const_in_env
    app.env = {'klass' => SetClass}
    assert_equal SetClass, app.call('sig' => 'resolve', 'args' => ['klass'])
  end
  
  def test_resolve_raises_error_for_unresolvable_const
    err = assert_raises(RuntimeError) { app.call('sig' => 'resolve', 'args' => ['missing']) }
    assert_equal "unresolvable constant: \"missing\"", err.message
  end
  
  #
  # build test
  #
  
  def test_build_builds_and_returns_object
    app.env = {'klass' => SetClass}
    obj = app.call('sig' => 'build', 'args' => ['klass'])
    assert_equal SetClass, obj.class
    assert_equal :parse!, obj.build_method
  end
  
  #
  # parse test
  #
  
  def test_parse_parses_and_builds_workflow
    app.env = {'klass' => SetClass}
    app.call('sig' => 'parse', 'args' => ['klass', 1, 2, '--/set', '3', 'klass'])
    
    assert_equal SetClass, app.get('0').class
    assert_equal SetClass, app.get('3').class
    
    zero = app.get('0')
    assert_equal [[zero, [1,2]]], app.queue.to_a
  end
  
  def test_parse_returns_remaining_args
    assert_equal ['a', 'b', 'c'], app.call('sig' => 'parse', 'args' => ['--/info', '---', 'a', 'b', 'c'])
  end
  
  def test_parse_does_not_use_bang_unless_specified
    app.bang = false
    
    args = ['--/info', '---', 'a', 'b', 'c']
    assert_equal ['a', 'b', 'c'], app.call('sig' => 'parse', 'args' => args)
    assert_equal ['--/info', '---', 'a', 'b', 'c'], args
    
    app.bang = true
    
    args = ['--/info', '---', 'a', 'b', 'c']
    assert_equal ['a', 'b', 'c'], app.call('sig' => 'parse', 'args' => args)
    assert_equal ['a', 'b', 'c'], args
  end
  
  #
  # use test
  #
  
  class UseClass < App::Api
    class << self
      def build(spec={}, app=Tap::App.instance)
        new(app.stack)
      end
    end
    
    attr_reader :stack
    def initialize(stack)
      @stack = stack
    end
  end
  
  def test_use_builds_and_sets_middleware
    app.env = {'klass' => UseClass}
    obj = app.call('sig' => 'use', 'args' => ['klass'])
    assert_equal UseClass, obj.class
    assert_equal [obj], app.middleware
  end
  
  #
  # configure test
  #
  
  def test_configure_reconfigures_app
    assert_equal false, app.verbose
    assert_equal app.config, app.call('sig' => 'configure', 'args' => ['--verbose'])
    assert_equal true, app.verbose
  end
  
  def test_configure_reconfigures_app_from_hash_args
    assert_equal false, app.verbose
    assert_equal app.config, app.call('sig' => 'configure', 'args' => {'verbose' => true})
    assert_equal true, app.verbose
  end
  
  #
  # reset test
  #
  
  def test_reset_resets_app
    n = app.node {}
    app.set(0, n)
    app.enq(n, 1)
    app.use UseClass
    
    assert_equal false, app.objects.empty?
    assert_equal 1, app.queue.size
    assert_equal 1, app.middleware.size
    
    assert_equal app, app.call('sig' => 'reset')
    
    assert_equal true, app.objects.empty?
    assert_equal 0, app.queue.size
    assert_equal 0, app.middleware.size
  end
  
  #
  # run test
  #
  
  def test_run_runs_app
    was_in_block = false
    n = app.node { was_in_block = true }
    app.enq(n)
    
    assert_equal app, app.call('sig' => 'run')
    assert_equal 0, app.queue.size
    assert_equal true, was_in_block
  end
  
  #
  # stop test
  #
  
  def test_stop_stops_app
    was_in_a = false
    a = app.node do
      was_in_a = true
      assert_equal app, app.call('sig' => 'stop')
      assert_equal App::State::STOP, app.state
    end
    
    was_in_b = false
    b = app.node do
      was_in_b = true
    end
    
    app.enq(a)
    app.enq(b)
    
    app.run
    assert_equal true, was_in_a
    assert_equal false, was_in_b
    assert_equal 1, app.queue.size
  end
  
  #
  # terminate test
  #
  
  def test_terminate_terminates_app
    was_in_a = false
    a = app.node do
      was_in_a = true
      assert_equal app, app.call('sig' => 'terminate')
      assert_equal App::State::TERMINATE, app.state
    end
    
    was_in_b = false
    b = app.node do
      was_in_b = true
    end
    
    app.enq(a)
    app.enq(b)
    
    app.run
    assert_equal true, was_in_a
    assert_equal false, was_in_b
    assert_equal 1, app.queue.size
  end
  
  #
  # info test
  #
  
  def test_info_returns_info_string
    assert_equal app.info, app.call('sig' => 'info')
  end
end
