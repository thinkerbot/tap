require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/controllers/data'

class Tap::Controllers::DataTest < Test::Unit::TestCase
  Data = Tap::Controllers::Data
  
  acts_as_tap_test
  acts_as_subset_test
  cleanup_dirs << :views << :public
  
  attr_reader :env, :server, :request
  
  def setup
    super
    @env = Tap::Env.new(:root => method_root, :env_paths => TEST_ROOT)
    @server = Tap::Server.new Data, :env => env, :router => false
    @request = Rack::MockRequest.new(server)
  end
  
  #
  # create test
  #
  
  def test_create_raises_error_for_reserved_id
    controller = Class.new(Data)
    controller.get(:reserved_ids) << "reserved"
    
    server.controller = controller
    res = request.post("/reserved")
    
    assert_equal 500, res.status
    assert_match(/reserved id: "reserved"/, res.body)
  end
  
  #
  # rename test
  #
  
  def test_rename_raises_error_for_reserved_new_id
    controller = Class.new(Data)
    controller.get(:reserved_ids) << "reserved"
    
    server.controller = controller
    res = request.post("/1?_method=rename&new_id=reserved")
    
    assert_equal 500, res.status
    assert_match(/reserved id: "reserved"/, res.body)
  end
  
  def test_rename_raises_error_for_no_new_id_specified
    res = request.post("/1?_method=rename")
    assert_equal 500, res.status
    assert_match(/no new id specified/, res.body)
  end
  
  #
  # duplicate test
  #
  
  def test_duplicate_raises_error_for_reserved_new_id
    controller = Class.new(Data)
    controller.get(:reserved_ids) << "reserved"
    
    server.controller = controller
    res = request.post("/1?_method=duplicate&new_id=reserved")
    
    assert_equal 500, res.status
    assert_match(/reserved id: "reserved"/, res.body)
  end
end