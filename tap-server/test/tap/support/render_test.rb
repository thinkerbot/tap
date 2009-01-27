require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/render'

class RenderTest < Test::Unit::TestCase
  include Tap::Support::Render
  
  acts_as_file_test
  cleanup_dirs << :views
  
  # note env is required for Render
  attr_accessor :env
  
  def setup
    super
    @env = Tap::Env.new(method_root)
  end
  
  #
  # render test
  #
  
  def test_render_renders_template
    method_root.prepare(:views, 'one.erb') {|file| file << "<%= 1 + 2 %>" }
    assert_equal "3", render('one')
  end
  
  def test_render_renders_erb_as_erb
    method_root.prepare(:views, 'one.erb') {|file| file << "<%= 1 + 2 %>" }
    assert_equal "3", render('one.erb')
  end
  
  def test_render_renders_nested_templates
    method_root.prepare(:views, 'one.erb') {|file| file << "one:<%= render('two') %>" }
    method_root.prepare(:views, 'two.erb') {|file| file << "two:<%= 'thr' + 'ee' %>" }
    
    assert_equal "one:two:three", render('one')
  end
  
  def test_render_sets_locals
    method_root.prepare(:views, 'one.erb') {|file| file << "<%= local %>" }
    assert_equal "value", render('one', :locals => {:local => 'value'})
  end

  def test_render_does_not_pass_locals_to_nested_template
    method_root.prepare(:views, 'one.erb') {|file| file << "<%= local %>:<%= render('two') %>" }
    method_root.prepare(:views, 'two.erb') {|file| file << "<%= local %>:three" }
    
    assert_equal "one::three", render('one', :locals => {:local => 'one'})
  end
  
  def test_render_sets_nested_locals_to_nested_template
    method_root.prepare(:views, 'one.erb') {|file| file << "<%= local %>:<%= render('two', :locals => {:local => 'two'}) %>" }
    method_root.prepare(:views, 'two.erb') {|file| file << "<%= local %>:three" }
    
    assert_equal "one:two:three", render('one', :locals => {:local => 'one'})
  end
  
  def test_render_sets_env_as_local
    method_root.prepare(:views, 'one.erb') {|file| file << "<%= env.object_id %>" }
    assert_equal "#{env.object_id}", render('one')
  end

  def test_render_raises_error_if_env_local_is_set
    method_root.prepare(:views, 'one.erb') {|file| file << "<%= env.object_id %>" }

    err = assert_raises(ArgumentError) { render('one', :locals => {:env => nil}) }
    assert_equal "locals specifies env", err.message

    err = assert_raises(ArgumentError) { render('one', :locals => {'env' => nil}) }
    assert_equal "locals specifies env", err.message
  end
  
  def test_render_raises_error_if_template_cannot_be_found
    err = assert_raises(ArgumentError) { render('one') }
    assert_equal "no such thing: \"one\"", err.message
  end
  
end