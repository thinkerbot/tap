require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test/env_vars'

class EnvVarsTest < Test::Unit::TestCase
  include Tap::Test::EnvVars
  
  def setup
    @env_hold = {}
    ENV.each_pair do |key, value|
      @env_hold[key] = value
    end
    ENV.clear
  end
  
  def teardown
    ENV.clear
    @env_hold.each_pair do |key, value|
      ENV[key] = value
    end
  end
  
  #
  # env test
  #
  
  def test_env_access_is_case_insensitive
    ENV['key1'] = "value"
    assert_equal 'value', env('key1')
    assert_equal 'value', env('KEY1')
    
    ENV['KEY2'] = "VALUE"
    assert_equal 'VALUE', env('key2')
    assert_equal 'VALUE', env('KEY2')
  end
  
  def test_env_raises_error_if_multiple_values_can_be_selected
    ENV['key'] = "value"
    ENV['KEY'] = "VALUE"
    
    # Some platforms (ex Windows) already make ENV case-independent
    # Filter for the platforms that do not by checking that ENV has both
    # expected keys
    if ENV.length == 2
      assert_raise(RuntimeError) { env('key') }
      assert_raise(RuntimeError) { env('Key') }
    end
  end

end