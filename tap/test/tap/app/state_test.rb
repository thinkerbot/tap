require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/app/state'

class StateTest < Test::Unit::TestCase
  State = Tap::App::State
  
  #
  #  State test
  #
  
  def test_state_str_documentation
    assert_equal 'READY', State.state_str(0)
    assert_nil State.state_str(12)
  end
end