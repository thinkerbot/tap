require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/env'

class EnvSignalsTest < Test::Unit::TestCase
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
  # loadpath test
  #
  
  def test_loadpath_adds_paths_to_LOAD_PATH
    current = $LOAD_PATH.dup
    begin
      $LOAD_PATH.clear
      
      assert_equal $LOAD_PATH, signal('loadpath', '/a', '/b/c')
      assert_equal ['/a', '/b/c'], $LOAD_PATH
    ensure
      $LOAD_PATH.concat(current)
    end
  end
  
  #
  # unloadpath test
  #
  
  def test_unloadpath_deletes_paths_to_LOAD_PATH
    current = $LOAD_PATH.dup
    begin
      $LOAD_PATH.clear
      $LOAD_PATH.concat ['/a', '/b/c', '/d', '/e']
      
      assert_equal $LOAD_PATH, signal('unloadpath', '/e', '/b/c')
      assert_equal ['/a', '/d'], $LOAD_PATH
    ensure
      $LOAD_PATH.concat(current)
    end
  end
end
