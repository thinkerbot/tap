require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/env'
require 'tap/test'

class EnvSignalsTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test
  
  Env = Tap::Env
  
  attr_reader :env
  
  def setup
    super
    @env = Env.new
  end
  
  def signal(sig, *args)
    env.signal(sig).call(args)
  end
  
  #
  # lp test
  #
  
  def test_lp_adds_paths_to_LOAD_PATH
    current = $LOAD_PATH.dup
    begin
      $LOAD_PATH.clear
      
      assert_equal $LOAD_PATH, signal('lp', '/a', '/b/c')
      assert_equal ['/a', '/b/c'], $LOAD_PATH
    ensure
      $LOAD_PATH.concat(current)
    end
  end
  
  #
  # unlp test
  #
  
  def test_unlp_deletes_paths_to_LOAD_PATH
    current = $LOAD_PATH.dup
    begin
      $LOAD_PATH.clear
      $LOAD_PATH.concat ['/a', '/b/c', '/d', '/e']
      
      assert_equal $LOAD_PATH, signal('unlp', '/e', '/b/c')
      assert_equal ['/a', '/d'], $LOAD_PATH
    ensure
      $LOAD_PATH.concat(current)
    end
  end
end
