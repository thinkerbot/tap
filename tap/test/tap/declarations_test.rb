require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/declarations'

class DeclarationsTest < Test::Unit::TestCase
  
  #
  # node test
  #
  
  def test_node_interns_node_that_calls_block
    n = app.node {|input| input + " was provided" }
    assert n.kind_of?(App::Node)
    assert_equal "str was provided", n.call(["str"])
  end
  
  def test_node_sets_node_in_objects_by_var_if_specified
    n = app.node('var') {}
    assert_equal n, app.get('var')
  end
  
  #
  # join test
  #
  
  class JoinMock
    attr_reader :args, :inputs, :outputs
    def initialize(*args)
      @args = args
    end
    
    def join(inputs, outputs)
      @inputs = inputs
      @outputs = outputs
    end
  end
  
  def test_join_joins_inputs_and_outputs_with_configs
    a = app.node 
    b = app.node 
    join = app.join([a], [b], {:arrayify => true}, JoinMock)
    
    assert_equal [a], join.inputs
    assert_equal [b], join.outputs
    assert_equal [{:arrayify => true}, app], join.args
  end
end