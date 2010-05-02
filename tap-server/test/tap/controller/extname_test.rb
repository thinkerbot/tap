require  File.join(File.dirname(__FILE__), '../../test_helper')
require 'tap/controller'

class ExtnameTest < Test::Unit::TestCase
  acts_as_file_test
  
  class ExtnameController < Tap::Controller
    include Extname
    
    def index
      "index"
    end
    
    def action(*args)
      args << extname if extname
      args.join(",")
    end
  end
  
  def test_extname_routes
    controller = ExtnameController.new
    request = Rack::MockRequest.new controller
    
    assert_equal "index", request.get("/").body
    assert_equal "", request.get("/action").body
    assert_equal ".js", request.get("/action.js").body
    assert_equal "a,b,c", request.get("/action/a/b/c").body
    assert_equal "a,b,c,.js", request.get("/action/a/b/c.js").body
  end
end