require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'tap/test'

class AppSignalsTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  App = Tap::App
  
  #
  # enq
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
  # pq
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
  # set
  #
  
  class SetClass < App::Api
    class << self
      def build(spec, app)
        obj = super
        obj.build_method ||= :build
        obj
      end
      
      def parse(argv, app)
        obj, args = super
        obj.build_method ||= :parse
        [obj, args]
      end
      
      def parse!(argv, app)
        obj, args = super
        obj.build_method ||= :parse!
        [obj, args]
      end
      
      def minikey
        "klass"
      end
    end
    
    config :key, 'value'
    attr_accessor :build_method
  end
  
  def test_set_instantiates_class_as_resolved_by_env
    app.env = {'klass' => SetClass}
    
    obj, args = app.call('sig' => 'set', 'class' => 'klass')
    assert_equal SetClass, obj.class
    assert_equal 'value', obj.key
    assert_equal app, obj.app
  end
  
  def test_set_raises_error_for_unresolvable_class
    app.env = {}
    err = assert_raises(RuntimeError) { app.call('sig' => 'set', 'class' => 'klass') }
    assert_equal "unresolvable constant: \"klass\"", err.message
  end
  
  def test_set_initializes_with_spec_if_specified
    app.env = {'klass' => SetClass}
    
    obj, args = app.call(
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
  
  def test_set_uses_spec_as_spec_if_spec_is_not_specified
    app.env = {'klass' => SetClass}
    
    obj, args = app.call(
      'sig' => 'set',
      'class' => 'klass',
      'config' => {'key' => 'alt'})
    assert_equal 'alt', obj.key
  end
  
  def test_set_stores_obj_by_var_if_specified
    app.env = {'klass' => SetClass}
    
    obj, args = app.call('sig' => 'set', 'class' => 'klass')
    assert_equal({}, app.objects)
    
    obj, args = app.call('sig' => 'set', 'var' => 'variable', 'class' => 'klass')
    assert_equal({'variable' => obj}, app.objects)
  end
  
  def test_set_stores_obj_by_multiple_var_if_specified
    app.env = {'klass' => SetClass}
    
    obj, args = app.call('sig' => 'set', 'class' => 'klass')
    assert_equal({}, app.objects)
    
    obj, args = app.call('sig' => 'set', 'var' => ['a', 'b'], 'class' => 'klass')
    assert_equal({'a' => obj, 'b' => obj}, app.objects)
  end
end
