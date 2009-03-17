require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/controller'

class ControllerTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :views << :data << :log
  
  attr_reader :controller, :server
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(method_root)
    @controller = Tap::Controller.new @server
  end
  
  #
  # inheritance test
  #
  
  class ParentController < Tap::Controller
    set :actions, [:a, :b, :c]
    set :middleware, [[Rack::Session::Cookie, [], nil]]
    set :default_layout, 'default'
  end
  
  class ChildController < ParentController
  end
  
  def test_actions_are_inherited_by_duplication
    assert_equal [:a, :b, :c], ChildController.actions
    assert ParentController.actions.object_id != ChildController.actions.object_id
  end
  
  def test_default_layout_is_inherited
    assert_equal 'default', ChildController.default_layout
  end
  
  def test_name_is_underscored_class_name
    assert_equal "controller_test/parent_controller", ParentController.name
    assert_equal "controller_test/child_controller", ChildController.name
  end
  
  #
  # actions test
  #
  
  def test_action_are_empty_by_default
    assert Tap::Controller.actions.empty?
  end
  
  class ActionController < Tap::Controller
    def public_method
    end
    
    protected
    
    def protected_method
    end
    
    private
    
    def private_method
    end
    
    public
    
    def another_public_method
    end
  end
  
  def test_public_methods_in_subclasses_are_automatically_registered_as_actions
    assert_equal [:public_method, :another_public_method], ActionController.actions
  end
  
  #
  # rest routes test
  #
  
  class RESTController < Tap::Controller
    use_rest_routes :projects
    
    # GET /projects
    def index
      "index"
    end
    
    # GET /projects/1
    def show(id)
      "show #{id}"
    end
    
    # GET /projects/1;edit
    def edit(id)
      "edit #{id}"
    end
    
    # POST /projects/1
    def create(id)
      "create #{id}"
    end
    
    # PUT /projects/1
    def update(id)
      "update #{id}"
    end
    
    # DELETE /projects/1
    def destroy(id)
      "destroy #{id}"
    end
  end
  
  def test_rest_routes
    controller = RESTController.new server
    request = Rack::MockRequest.new controller
    
    assert_equal "index", request.get("/projects").body
    assert_equal "show 1", request.get("/projects/1").body
    assert_equal "edit 1", request.get("/projects/1;edit").body
    assert_equal "create 1", request.post("/projects/1").body
    assert_equal "update 1", request.put("/projects/1").body
    assert_equal "destroy 1", request.delete("/projects/1").body
  end
  
  def test_rest_routing_raises_error_for_unknown_request_method
    env = Rack::MockRequest.env_for("/projects", 'REQUEST_METHOD' => 'UNKNOWN')
    controller = RESTController.new server
    
    e = assert_raises(Tap::ServerError) { controller.call(env) }
    assert_equal "unknown request method: UNKNOWN", e.message
  end
  
  #
  # render_erb test
  #
  
  def test_render_erb
    assert_equal "one:two", controller.render_erb("<%= %w{one two}.join(':') %>")
  end
  
  def test_render_erb_sets_locals
    assert_equal "value", controller.render_erb("<%= local %>", :locals => {:local => 'value'})
  end
  
  def test_render_nested_erb_templates
    one = "one:<%= render_erb(local, :locals => {:local => 'three'}) %>"
    two = "two:<%= local %>"
    
    assert_equal "one:two:three", controller.render_erb(one, :locals => {:local => two})
  end
  
  def test_render_erb_does_not_pass_locals_to_nested_template
    one = "<%= render_erb(two) %>"
    two = "<%= local %>"
    
    e = assert_raises(NameError) { controller.render_erb(one, :locals => {:local => 'one', :two=> two}) }
    assert e.message =~ /undefined local variable or method \`local\' for/
  end
  
  def test_render_erb_does_not_change_state_of_controller
    previous = {}
    controller.instance_variables.each {|var| previous[var] = controller.instance_variable_get(var) } 
    
    controller.render_erb("<%= local %>", :locals => {:local => 'value'})
     
    current = {}
    controller.instance_variables.each {|var| current[var] = controller.instance_variable_get(var) }
    assert_equal previous, current
  end
  
  #
  # render test
  #
  
  class NamedController < Tap::Controller
    set :name, "name"
  end
  
  def test_render_prepends_controller_name_to_path
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    method_root.prepare(:views, 'name/sample.erb') {|file| file << "<%= %w{one two three}.join(':') %>" }
    
    name_controller = NamedController.new server
    
    assert_equal "one:two", controller.render('sample.erb')
    assert_equal "one:two:three", name_controller.render('sample.erb')
  end
  
  def test_render_looks_up_template_directly
    method_root.prepare(:views, 'alt/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    
    name_controller = NamedController.new server
    
    assert_equal "one:two", controller.render(:template => 'alt/sample.erb')
    assert_equal "one:two", name_controller.render(:template => 'alt/sample.erb')
  end
  
  def test_render_assigns_locals
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= local %>" }
    assert_equal "value", controller.render('sample.erb', :locals => {:local => 'value'})
  end
  
  def test_render_renders_a_layout_template_with_content_if_specified
    method_root.prepare(:views, 'layout.erb') {|file| file << "<html><%= content %></html>" }
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    
    assert_equal "<html>one:two</html>", controller.render('sample.erb', :layout => 'layout.erb')
  end
  
  class DefaultLayoutController < Tap::Controller
    set :default_layout, 'layout.erb'
    set :name, ""
  end
  
  def test_render_uses_default_layout_for_layout_true
    method_root.prepare(:views, 'layout.erb') {|file| file << "<html><%= content %></html>" }
    method_root.prepare(:views, 'sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    
    controller = DefaultLayoutController.new server
    assert_equal "<html>one:two</html>", controller.render('sample.erb', :layout => true)
  end
  
  #
  # call test
  #
  
  class CallController < Tap::Controller
    def action(*args)
      args.join(".")
    end
  end
  
  def test_controller_routes_path_info_to_action_and_args
    request = Rack::MockRequest.new CallController
    assert_equal "a.b.c", request.get("/action/a/b/c").body
  end
  
  def test_controller_chomps_extname_off_action_if_specified
    request = Rack::MockRequest.new CallController
    assert_equal "a.b.c", request.get("/action.ext/a/b/c").body
  end
  
  def test_call_correctly_routes_path_info_with_escapes
    request = Rack::MockRequest.new CallController
    assert_equal "a+b.c d", request.get("/%61ction/a%2Bb/c%20d").body
  end
  
  def test_call_raises_a_server_error_if_path_info_cannot_be_routed_to_an_action
    request = Rack::MockRequest.new CallController
    e = assert_raises(Tap::ServerError) { request.get("/not_an_action") }
    assert_equal "404 Error: page not found", e.message
  end
  
  class ResponseController < Tap::Controller
    def action
      response.status = 201
      "body"
    end
  end
  
  def test_actions_may_modifiy_response
    request = Rack::MockRequest.new ResponseController
    response = request.get("/action")
    assert_equal 201, response.status
    assert_equal "body", response.body
  end
  
  class NonStringResponseController < Tap::Controller
    def action
      [201, {}, ["body"]]
    end
  end
  
  def test_non_string_responses_are_returned_directly
    request = Rack::MockRequest.new NonStringResponseController
    response = request.get("/action")
    assert_equal 201, response.status
    assert_equal "body", response.body
  end
  
  class IndexController < Tap::Controller
    def index
      "result"
    end
  end
  
  def test_empty_path_routes_to_index
    request = Rack::MockRequest.new IndexController
    assert_equal "result", request.get("/").body
  end
  
  #
  # session test
  #
  
  def test_session_returns_the_rack_session
    session = {}
    request = Rack::Request.new Rack::MockRequest.env_for("/", 'rack.session' => session)
    controller = Tap::Controller.new nil, request
    
    assert_equal session.object_id, controller.session.object_id
  end
  
  def test_session_initializes_rack_session_as_a_hash_if_necessary
    request = Rack::Request.new Rack::MockRequest.env_for("/")
    controller = Tap::Controller.new nil, request
    
    assert !request.env.has_key?('rack.session')
    session = controller.session
    assert_equal({}, session)
    assert_equal session.object_id, request.env['rack.session'].object_id
  end
  
  #
  # app test
  #
  
  class MockAppServer
    def initialize_session
      1
    end
    def app(id)
      "app_#{id}"
    end
  end
  
  def test_app_returns_server_app_for_session_id
    request = Rack::Request.new Rack::MockRequest.env_for("/", 'rack.session' => {:id => 0})
    controller = Tap::Controller.new MockAppServer.new, request
    assert_equal 'app_0', controller.app
  end
  
  def test_app_initializes_session_id_if_unspecified
    request = Rack::Request.new Rack::MockRequest.env_for("/")
    controller = Tap::Controller.new MockAppServer.new, request
    
    assert !request.env.has_key?('rack.session')
    assert_equal 'app_1', controller.app
    assert_equal({:id => 1}, request.env['rack.session'])
  end
  
  #
  # root test
  #
  
  class MockRootServer
    def initialize_session
      1
    end
    def root(id)
      "root_#{id}"
    end
  end
  
  def test_root_returns_server_root_for_session_id
    request = Rack::Request.new Rack::MockRequest.env_for("/", 'rack.session' => {:id => 0})
    controller = Tap::Controller.new MockRootServer.new, request
    assert_equal 'root_0', controller.root
  end
  
  def test_root_initializes_session_id_if_unspecified
    request = Rack::Request.new Rack::MockRequest.env_for("/")
    controller = Tap::Controller.new MockRootServer.new, request
    
    assert !request.env.has_key?('rack.session')
    assert_equal 'root_1', controller.root
    assert_equal({:id => 1}, request.env['rack.session'])
  end
  
  #
  # persistence test
  #
  
  class MockPersistenceServer
    def initialize(root)
      @root = root
    end
    def initialize_session
      1
    end
    def root(id)
      @root
    end
  end
  
  def test_persistence_returns_a_Persistence_object_initialized_to_root
    request = Rack::Request.new Rack::MockRequest.env_for("/")
    controller = Tap::Controller.new MockPersistenceServer.new(method_root), request
    
    p = controller.persistence
    assert_equal Tap::Support::Persistence, p.class
    assert_equal method_root, p.root
  end
  
  class PersistenceController < Tap::Controller
    use_rest_routes :resource
    
    def persistence_root
      persistence.root.root
    end
    
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
    
    assert_equal method_root.root, request.get("/persistence_root", opts).body
    
    assert_equal "", request.get("/resource", opts).body
    assert_equal "", request.get("/resource/1", opts).body
    
    # create
    path = method_root.filepath(:data, "1")
    assert_equal path, request.post("/resource/1", opts).body
    assert_equal "create", File.read(path)
    
    assert_equal "1", request.get("/resource", opts).body
    assert_equal "create", request.get("/resource/1", opts).body
    
    # update
    assert_equal path, request.put("/resource/1", opts).body
    assert_equal "update", File.read(path)
    
    assert_equal "1", request.get("/resource", opts).body
    assert_equal "update", request.get("/resource/1", opts).body
    
    # destroy
    assert_equal "true", request.delete("/resource/1", opts).body
    assert !File.exists?(path)
    
    assert_equal "", request.get("/resource", opts).body
    assert_equal "", request.get("/resource/1", opts).body
  end
  
  #
  # redirect test
  #
  
  class RedirectController < Tap::Controller
    def action
      redirect "/target"
    end
    
    def action_with_args
      redirect "/target", 300, {'Content-Type' => 'text/plain'}, "body"
    end
    
    def action_with_location_header
      redirect "/target", 302, {'Location' => 'overridden'}
    end
  end
  
  def test_redirect_returns_a_302_response_with_the_redirect_location_set
    request = Rack::MockRequest.new RedirectController
    response = request.get("/action", 'tap.server' => server)
    assert_equal 302, response.status
    assert_equal "/target", response.headers['Location']
    assert_equal "", response.body
  end
  
  def test_redirect_may_specify_status_headers_and_body
    request = Rack::MockRequest.new RedirectController
    response = request.get("/action_with_args", 'tap.server' => server)
    assert_equal 300, response.status
    assert_equal "/target", response.headers['Location']
    assert_equal "text/plain", response.headers['Content-Type']
    assert_equal "body", response.body
  end
  
  def test_redirect_uri_overrides_header_Location
    request = Rack::MockRequest.new RedirectController
    response = request.get("/action_with_location_header", 'tap.server' => server)
    assert_equal "/target", response.headers['Location']
  end
end