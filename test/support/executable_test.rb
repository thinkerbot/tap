require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/executable'

class ExecutableTest < Test::Unit::TestCase
  include Tap

  attr_accessor :m
  
  def setup
    @m = Tap::Support::Executable.initialize(Object.new, :object_id)
  end
  
  #
  # initialization tests
  #
  
  def test_initialization
    assert !m.multithread
    assert_nil m.on_complete_block
  end
  
  #
  # on_complete block test
  #
  
  def test_on_complete_sets_on_complete_block
    block = lambda {}
    m.on_complete(&block)
    assert_equal block, m.on_complete_block
  end
  
  def test_on_complete_can_only_be_set_once
    m.on_complete {}
    assert_raise(RuntimeError) { m.on_complete {} }
    assert_raise(RuntimeError) { m.on_complete }
  end

end