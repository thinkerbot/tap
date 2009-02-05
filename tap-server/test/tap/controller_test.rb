require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/controller'

class ControllerTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :views
  
  attr_reader :controller, :server
  
  def setup
    super
    @server = Tap::Server.new Tap::Env.new(method_root)
    @controller = Tap::Controller.new
    @controller.server = @server
  end
  
  #
  # action? test
  #
  
  def test_action_is_false_for_all_controller_methods
    controller.methods.each do |method|
      assert !controller.action?(method), method
    end
  end
  
  def test_action_returns_false_for_nil
    assert !controller.action?(nil)
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
  end
  
  def test_action_is_true_in_subclasses_for_new_public_methods
    a = ActionController.new
    assert a.action?(:public_method)
    assert !a.action?(:protected_method)
    assert !a.action?(:private_method)
  end
  
  def test_action_works_with_string_inputs
    a = ActionController.new
    assert a.action?('public_method')
    assert !a.action?('protected_method')
    assert !a.action?('private_method')
  end
  
  #
  # render_erb test
  #
  
  def test_render_erb
    assert_equal "3", controller.render_erb("<%= 1 + 2 %>")
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
  
  def test_render_looks_up_path_by_controller_name
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= 1 + 2 %>" }
    assert_equal "3", controller.render('sample.erb')
  end
  
  def test_render_looks_up_template
    method_root.prepare(:views, 'alt/sample.erb') {|file| file << "<%= 1 + 2 %>" }
    assert_equal "3", controller.render(:template => 'alt/sample.erb')
  end
  
  def test_render_assigns_locals
    method_root.prepare(:views, 'tap/controller/sample.erb') {|file| file << "<%= local %>" }
    assert_equal "value", controller.render('sample.erb', :locals => {:local => 'value'})
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
  
  def test_call_correctly_routes_path_info_with_escapes
    request = Rack::MockRequest.new CallController
    assert_equal "a+b.c d", request.get("/%61ction/a%2Bb/c%20d").body
  end
  
  def test_call_raises_a_server_error_if_path_info_cannot_be_routed_to_an_action
    request = Rack::MockRequest.new CallController
    e = assert_raises(Tap::ServerError) { request.get("/not_an_action") }
    assert_equal "404 Error: unknown action", e.message
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
end