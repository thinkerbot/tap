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
end
