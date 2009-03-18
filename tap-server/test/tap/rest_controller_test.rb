require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/rest_controller'

class RestControllerTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :views << :data << :log
  
  attr_reader :server
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(method_root)
  end
  
  #
  # rest routes test
  #
  
  class RestfulController < Tap::RestController
    def index
      "index"
    end
    
    def show(id)
      "show #{id}"
    end
    
    def edit(id)
      "edit #{id}"
    end
    
    def create(id)
      "create #{id}"
    end
    
    def update(id)
      "update #{id}"
    end
    
    def destroy(id)
      "destroy #{id}"
    end
  end
  
  def test_rest_routes
    controller = RestfulController.new server
    request = Rack::MockRequest.new controller
    
    assert_equal "index", request.get("/").body
    assert_equal "show 1", request.get("/1").body
    assert_equal "edit 1", request.get("/1;edit").body
    assert_equal "create 1", request.post("/1").body
    assert_equal "update 1", request.put("/1").body
    assert_equal "destroy 1", request.delete("/1").body
  end
  
  def test_rest_routing_raises_error_for_unknown_request_method
    env = Rack::MockRequest.env_for("/", 'REQUEST_METHOD' => 'UNKNOWN')
    controller = RestfulController.new server
    
    e = assert_raises(Tap::ServerError) { controller.call(env) }
    assert_equal "unknown request method: UNKNOWN", e.message
  end
  
  class PersistenceController < Tap::RestController
    set :use_rest_routes, true
    
    def index
      persistence.index.join(", ")
    end
    
    def show(id)
      persistence.read(id)
    end
    
    def create(id)
      persistence.create(id) {|io| io << "create" }
    end
    
    def update(id)
      persistence.update(id) {|io| io << "update" }
    end
    
    def destroy(id)
      persistence.destroy(id).to_s
    end
  end
  
  def test_a_sample_persistence_controller
    controller = PersistenceController.new
    request = Rack::MockRequest.new controller
    opts = {'tap.server' => server}
    
    assert_equal "", request.get("/", opts).body
    assert_equal "", request.get("/1", opts).body
    
    # create
    path = method_root.filepath(:data, "1")
    assert_equal path, request.post("/1", opts).body
    assert_equal "create", File.read(path)
    
    assert_equal "1", request.get("/", opts).body
    assert_equal "create", request.get("/1", opts).body
    
    # update
    assert_equal path, request.put("/1", opts).body
    assert_equal "update", File.read(path)
    
    assert_equal "1", request.get("/", opts).body
    assert_equal "update", request.get("/1", opts).body
    
    # destroy
    assert_equal "true", request.delete("/1", opts).body
    assert !File.exists?(path)
    
    assert_equal "", request.get("/", opts).body
    assert_equal "", request.get("/1", opts).body
  end
end