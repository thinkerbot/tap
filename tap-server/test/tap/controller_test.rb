require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'

class ControllerTest < Test::Unit::TestCase
  acts_as_tap_test
  
  attr_accessor :server
  
  class MockServer
    attr_reader :env
    def initialize(env)
      @env = env
    end
  end
  
  def setup
    super
    @server = MockServer.new(Tap::Env.new(method_root))
  end
  
  def assert_body(res, str)
    assert_alike Tap::Test::RegexpEscape.new(str.strip, Regexp::MULTILINE), res.body
  end
  
end