require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/controller'

class ControllerTest < Test::Unit::TestCase
  acts_as_tap_test
  
  cleanup_dirs << :root
  
  attr_reader :controller, :server
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(method_root)
    @controller = Tap::Controller.new
    @controller.server = server
  end
  
  #
  # inheritance test
  #
  
  class ParentController < Tap::Controller
    set :actions, [:a, :b, :c]
    set :default_action, 'alt'
    set :default_layout, 'default'
  end
  
  class ChildController < ParentController
  end
  
  def test_actions_are_inherited_by_duplication
    assert_equal [:a, :b, :c], ChildController.actions
    assert ParentController.actions.object_id != ChildController.actions.object_id
  end
  
  def test_default_action_is_inherited
    assert_equal 'alt', ChildController.default_action
  end
  
  def test_default_layout_is_inherited
    assert_equal 'default', ChildController.default_layout
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
  # call test
  #
  
  class CallController < Tap::Controller
    set :default_action, :default
    
    def default
      "default response"
    end
    
    def action(*args)
      args.join(".")
    end
  end
  
  def test_call_sets_server
    controller = CallController.new
    assert_equal nil, controller.server
    
    request = Rack::MockRequest.new controller
    request.get("/action", 'tap.server' => 'server')
    
    assert_equal 'server', controller.server
  end
  
  def test_call_routes_empty_path_info_default_action
    request = Rack::MockRequest.new CallController
    assert_equal "default response", request.get("").body
    
    request = Rack::MockRequest.new CallController
    assert_equal "default response", request.get("/").body
  end
  
  def test_call_routes_path_info_to_action_and_args
    request = Rack::MockRequest.new CallController
    assert_equal "a.b.c", request.get("/action/a/b/c").body
  end
  
  def test_call_correctly_routes_path_info_with_escapes
    request = Rack::MockRequest.new CallController
    assert_equal "a+b.c d", request.get("/%61ction/a%2Bb/c%20d").body
  end
  
  def test_call_raises_a_server_error_if_path_info_cannot_be_routed_to_an_action
    request = Rack::MockRequest.new CallController
    e = assert_raises(Tap::Server::ServerError) { request.get("/not_an_action") }
    assert_equal "404 Error: page not found", e.message
  end
  
  class CallActionController < Tap::Controller
    def simple
      "simple body"
    end

    def standard
      response["Content-Type"] = "text/plain"
      response.body << "standard body"
      response.finish
    end

    def custom
      [200, {"Content-Type" => "text/plain"}, ["custom body"]]
    end
  end
  
  def test_call_uses_string_returns_as_response_body
    request = Rack::MockRequest.new CallActionController
    response = request.get("/simple")
    assert_equal "simple body", response.body
  end
  
  def test_call_returns_non_string_responses_directly
    request = Rack::MockRequest.new CallActionController
    response = request.get("/standard")
    assert_equal "text/plain", response["Content-Type"]
    assert_equal "standard body", response.body
    
    request = Rack::MockRequest.new CallActionController
    response = request.get("/custom")
    assert_equal "text/plain", response["Content-Type"]
    assert_equal "custom body", response.body
  end
  
  class CallIndexController < Tap::Controller
    def index
      "result"
    end
  end
  
  def test_empty_path_routes_to_index
    request = Rack::MockRequest.new CallIndexController
    assert_equal "result", request.get("/").body
  end

  #
  # render test
  #
  
  class RenderController < Tap::Controller
  end
  
  def test_render_renders_class_path_for_path
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    method_root.prepare(:views, 'controller_test/render_controller/sample.erb') {|file| file << "<%= %w{one two three}.join(':') %>" }
    
    assert_equal "one:two", controller.render('sample.erb')
    
    render_controller = RenderController.new
    render_controller.server = server
    assert_equal "one:two:three", render_controller.render('sample.erb')
  end
  
  def test_render_looks_up_template_under_template_dir
    method_root.prepare(:views, 'alt/sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    assert_equal "one:two", controller.render(:template => 'alt/sample.erb')
  end
  
  def test_render_renders_file
    path = method_root.prepare(:views, 'sample.erb') {|file| file << "<%= %w{one two}.join(':') %>" }
    assert_equal "one:two", controller.render(:file => path)
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
    
    controller = DefaultLayoutController.new
    controller.server = server
    assert_equal "<html>one:two</html>", controller.render(:template => 'sample.erb', :layout => true)
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
  # session test
  #
  
  def test_session_returns_the_rack_session
    session = {}
    request = Rack::Request.new Rack::MockRequest.env_for("/", 'rack.session' => session)
    controller = Tap::Controller.new
    controller.request = request
    
    assert_equal session.object_id, controller.session.object_id
  end
  
  def test_session_initializes_rack_session_as_a_hash_if_necessary
    request = Rack::Request.new Rack::MockRequest.env_for("/")
    
    controller = Tap::Controller.new
    controller.request = request
    controller.server = server
    
    assert !request.env.has_key?('rack.session')
    session = controller.session
    assert_equal({:id => 0}, session)
    assert_equal session.object_id, request.env['rack.session'].object_id
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