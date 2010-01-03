require File.join(File.dirname(__FILE__), '../../tap_test_helper') 
require 'tap/tasks/sig'
require 'tap/test'

class SigTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  Sig = Tap::Tasks::Sig
  
  #
  # process test
  #
  
  def test_process_parses_and_invokes_signal
    sig = Sig.new
    assert_equal(app.info, sig.process('info'))
  end
end