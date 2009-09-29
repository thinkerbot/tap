require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/templater'
require 'tap/test'

class TemplaterTest < Test::Unit::TestCase
  Templater = Tap::Templater
  
  extend Tap::Test
  acts_as_file_test
  
  def version_test(version)
    if RUBY_VERSION =~ version
      yield
    end
  end
  
  def test_documentation
    t = Templater.new( "key: <%= value %>")
    t.value = "default"
    assert_equal "key: default", t.build
  
    t.value = "another"
    assert_equal "key: another", t.build
    
    e = ERB.new("<%= 1 + 2 %>")
    version_test(/^1\.8/) { assert_equal("_erbout = ''; _erbout.concat(( 1 + 2 ).to_s); _erbout", e.src) }
    version_test(/^1\.9/) { assert_equal("#coding:US-ASCII\n_erbout = ''; _erbout.concat(( 1 + 2 ).to_s); _erbout.force_encoding(__ENCODING__)", e.src) }
    
    template = %Q{
# Un-nested content
<% redirect do |target| %>
# Nested content
<% module_nest("Nesting::Module") { target } %>
<% end %>
}
    t = Templater.new(template)
    expected = %Q{
# Un-nested content
module Nesting
  module Module
    # Nested content
    
  end
end}   
    assert_equal(expected, t.build)
  end
  
  #
  # Templater.build_file test
  #
  
  def test_build_file_reads_file_and_templates
    path = method_root.prepare(:tmp, "template.erb") do |io|
      io << %Q{key: <%= attr %>}
    end
    
    assert_equal "key: value", Templater.build_file(path, {:attr => 'value'})
  end
  
  #
  # initialize test
  #
  
  def test_initialize_raises_error_for_non_string_or_erb_template
    err = assert_raises(ArgumentError) { Templater.new nil }
    assert_equal "cannot convert NilClass into an ERB template", err.message
    err = assert_raises(ArgumentError) { Templater.new 1 }
    assert_equal "cannot convert Fixnum into an ERB template", err.message
  end
  
  #
  # build test
  #
  
  def test_build_formats_erb_with_existing_attributes
    t = Templater.new %Q{key: <%= attr %>}, {:attr => 'value'}
    assert_equal "key: value", t.build
  end
  
  def test_build_with_custom_erb
    erb = ERB.new "% factor = 2\nkey: <%= attr * factor %>", nil, "%"
    
    t = Templater.new erb, {:attr => 'value'}
    assert_equal "key: valuevalue", t.build
  end
  
  def test_build_sets_attributes_if_specified
    t = Templater.new %Q{key: <%= attr %>}
    assert_equal "key: value", t.build(:attr => 'value')
    assert_equal "key: alt", t.build(:attr => 'alt')
  end
  
  def test_build_sets_filename_if_specified
    t = Templater.new %Q{<% raise 'error!' %>}
    err = assert_raises(RuntimeError) { t.build(nil, 'filename') }
    assert_equal 'error!', err.message
    assert err.backtrace[0] =~ /filename:1:in /
  end
  
end
