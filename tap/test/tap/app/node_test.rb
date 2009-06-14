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
    assert_equal [], m.joins
    assert_equal "result", m.call
  end
  
  #
  # extend tests
  #
  
  def test_extend_initializes_defaults
    m = lambda {}.extend Node
    assert m.kind_of?(Node)
    assert_equal [], m.joins
  end
  
  #
  # on_complete test
  #
  
  def test_on_complete_sets_a_join_for_self
    assert_equal [], m.joins

    b = lambda {}
    m.on_complete(&b)
    
    assert_equal [b], m.joins
  end
  
  def test_on_complete_returns_self
    assert_equal m, m.on_complete
  end
end