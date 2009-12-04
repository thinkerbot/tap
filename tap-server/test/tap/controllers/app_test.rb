require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/app'

class Tap::Controllers::AppTest < Test::Unit::TestCase
  acts_as_tap_test :cleanup_dirs => [:lib, :views, :public]
  
  attr_reader :server, :request
  
  def setup
    super
    @server = Tap::Server.new.bind(Tap::Controllers::Server)
    @request = Rack::MockRequest.new(@server)
  end
  
  def app
    server.app
  end
  
  def env_config
    config = super
    config[:env_paths] = TEST_ROOT
    config
  end
  
  #
  # signal test
  #
  
  class Sample < Tap::App::Api
  end
  
  def test_post_signals_invokes_signal_on_app
    app.env.register(Sample)
    assert_equal({}, app.objects)
    
    response = request.post("/app/set?class=sample&var=0")
    assert_equal 200, response.status, response.body
    
    assert_equal(Sample, app.objects["0"].class)
  end
end