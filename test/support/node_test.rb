require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/node'

class NodeTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :node
  
  def setup
    @node = Node.new
  end
    
  #
  # reset test
  #
  
  def test_reset_sets_input_and_output_to_nil
    node.input = :input
    node.output = :output
    
    node.reset
    
    assert_equal nil, node.input
    assert_equal nil, node.output
  end
  
end