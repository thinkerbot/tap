require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/server'
require 'tap/test/regexp_escape'

class ServerTest < Test::Unit::TestCase
  acts_as_tap_test
  
  attr_accessor :server, :request
  
  def setup
    super
    @server = Tap::Server.new(:env => Tap::Env.new(method_root))
    @request = Rack::MockRequest.new(@server)
  end
  
  def assert_body(res, str)
    assert_alike Tap::Test::RegexpEscape.new(str.strip, Regexp::MULTILINE), res.body
  end
end
