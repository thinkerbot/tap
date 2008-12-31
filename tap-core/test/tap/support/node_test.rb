require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/node'

class NodeTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :node
  
  def setup
    @node = Node.new
  end
    
  #
  # globalize test
  #
  
  def test_globalize_sets_input_and_output_to_nil
    node.input = :input
    node.output = :output
    
    node.globalize
    
    assert_equal nil, node.input
    assert_equal nil, node.output
  end
  
  #
  # global? test
  #

  def test_is_true_if_input_and_output_are_nil
    assert_equal nil, node.input
    assert_equal nil, node.output
    
    assert node.global?
    
    node.input = :input
    assert !node.global?
    
    node.input = nil
    node.output = :output
    assert !node.global?
  end
  
  #
  # round test
  #

  def test_round_returns_input_if_input_is_an_integer
    node.input = 1
    assert_equal 1, node.round  
  end
  
  def test_round_returns_nil_if_input_is_not_an_integer
    node.input = nil
    assert_equal nil, node.round
    
    node.input = :input
    assert_equal nil, node.round
  end
    
  #
  # round= test
  #
  
  def test_set_round_is_an_alias_for_set_input
    assert_equal nil, node.input
    node.round = :input
    assert_equal :input, node.input
  end
end