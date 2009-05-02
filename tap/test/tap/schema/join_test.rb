require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/schema/join'

class SchemaJoinTest < Test::Unit::TestCase
  Join = Tap::Schema::Join
  
  attr_reader :join
  
  def setup
    @join = Join.new
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    join = Join.new
    assert_equal nil, join.metadata
    assert_equal [], join.inputs
    assert_equal [], join.outputs
  end
  
  #
  # orphan? test
  #
  
  def test_orphan_is_true_if_inputs_are_empty
    assert join.orphan?
    join.inputs << 1
    assert !join.orphan?
  end
end
