require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/renderer'

class RendererTest < Test::Unit::TestCase
  include Tap::Support
  
  acts_as_file_test
  
  attr_accessor :r
  
  def setup
    super
    @r = Renderer.new
  end
  
  #
  # Renderer.intern test
  #
  
  def test_intern_creates_a_new_renderer_with_block_as_template_path
    r = Renderer.intern {|renderer, thing| "#{thing} in block" }
    assert_equal "value in block", r.template_path("value")
  end
  
  #
  # initialize test
  #
  
  def test_default_initialize
    r = Renderer.new
    assert_equal nil, r.default_layout
  end
  
  def test_initialize
    r = Renderer.new "layout_path"
    assert_equal "layout_path", r.default_layout
  end
  
  #
  # render_erb test
  #
  
  def test_render_erb
    assert_equal "3", r.render_erb("<%= 1 + 2 %>")
  end
  
  def test_render_erb_sets_locals
    assert_equal "value", r.render_erb("<%= local %>", :local => 'value')
  end
  
  def test_render_nested_erb_templates
    one = "one:<%= render_erb(local, :local => 'three') %>"
    two = "two:<%= local %>"
    
    assert_equal "one:two:three", r.render_erb(one, :local => two)
  end
  
  def test_render_erb_does_not_pass_locals_to_nested_template
    one = "<%= render_erb(two) %>"
    two = "<%= local %>"
    
    e = assert_raises(NameError) { r.render_erb(one, :local => 'one', :two=> two) }
    assert e.message =~ /undefined local variable or method \`local\' for/
  end
  
  def test_render_erb_does_not_change_state_of_renderer
    previous = {}
    r.instance_variables.each {|var| previous[var] = r.instance_variable_get(var)} 
    
    r.render_erb("<%= local %>", :local => 'value')
     
    current = {}
    r.instance_variables.each {|var| current[var] = r.instance_variable_get(var)}
    assert_equal previous, current
  end
  
  #
  # render test
  #
  
  def test_render_renders_erb_paths_as_erb
    path = method_root.prepare(:tmp, 'sample.erb') {|file| file << "<%= 1 + 2 %>" }
    assert_equal "3", r.render(path)
  end
  
  def test_render_assigns_erb_locals
    path = method_root.prepare(:tmp, 'sample.erb') {|file| file << "<%= local %>" }
    assert_equal "value", r.render(path, :locals => {:local => 'value'})
  end
  
  def test_render_renders_unknown_file_extensions_by_reading_them
    path = method_root.prepare(:tmp, 'sample.txt') {|file| file << "<%= 'unrendered' %>" }
    assert_equal "<%= 'unrendered' %>", r.render(path)
  end
  
  def test_render_renders_default_layout_if_no_layout_is_specified
    path = method_root.prepare(:tmp, 'one.erb') {|file| file << "<%= 1 + 2 %>" }
    layout = method_root.prepare(:tmp, 'layout.erb') {|file| file << "sum = <%= content %>" }
    
    r.default_layout = layout
    assert_equal "sum = 3", r.render(path)
  end
  
  def test_render_does_not_render_default_layout_if_specified
    path = method_root.prepare(:tmp, 'one.erb') {|file| file << "<%= 1 + 2 %>" }
    layout = method_root.prepare(:tmp, 'layout.erb') {|file| file << "sum = <%= content %>" }
    
    r.default_layout = layout
    assert_equal "3", r.render(path, :layout => false)
    assert_equal "3", r.render(path, :layout => nil)
  end
  
  def test_render_renders_layout_specified_in_options
    path = method_root.prepare(:tmp, 'one.erb') {|file| file << "<%= 1 + 2 %>" }
    layout = method_root.prepare(:tmp, 'layout.erb') {|file| file << "sum = <%= content %>" }
    
    assert_equal "sum = 3", r.render(path, :layout => layout)
  end
end