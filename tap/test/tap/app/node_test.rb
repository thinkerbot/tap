require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/node'

class NodeTest < Test::Unit::TestCase
  Node = Tap::App::Node

  attr_accessor :m
  
  def setup
    @m = Node.intern {}
  end
  
  #
  # intern tests
  #
  
  def test_intern_makes_node_from_block
    m = Node.intern { "result" }
    assert m.kind_of?(Node)
    assert_equal nil, m.join
    assert_equal [], m.dependencies
    assert_equal "result", m.call
  end
  
  #
  # extend tests
  #
  
  def test_extend_initializes_defaults
    m = lambda {}.extend Node
    assert m.kind_of?(Node)
    assert_equal nil, m.join
    assert_equal [], m.dependencies
  end
  
  #
  # node? tests
  #
  
  def test_node_returns_true_if_obj_satisifies_the_node_API
    n = Node.intern {}
    assert Node.node?(n)
    
    m = Object.new
    assert !Node.node?(m)
    
    m.extend(Module.new {def join; end})
    assert !Node.node?(m)
    
    m.extend(Module.new {def dependencies; end})
    assert Node.node?(m)
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_sets_join_for_self
    assert_equal nil, m.join

    b = lambda {}
    m.on_complete(&b)
    
    assert_equal b, m.join
  end
  
  def test_on_complete_returns_self
    assert_equal m, m.on_complete
  end
  
  #
  # depends_on test
  #
  
  def test_depends_on_pushes_dependency_onto_dependencies
    m.dependencies << nil
    
    d1 = Node.intern {}
    m.depends_on(d1)
    assert_equal [nil, d1], m.dependencies
  end
  
  def test_depends_on_does_not_add_duplicates
    d1 = Node.intern {}
    m.dependencies << d1
    
    m.depends_on(d1)
    assert_equal [d1], m.dependencies
  end
  
  def test_depends_on_raises_error_for_self_as_dependency
    err = assert_raises(RuntimeError) { m.depends_on m }
    assert_equal "cannot depend on self", err.message
  end
end