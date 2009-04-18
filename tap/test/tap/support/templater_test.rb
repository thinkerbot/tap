require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/templater'

class TemplaterTest < Test::Unit::TestCase
  include Tap::Support
  
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
  # initialize test
  #
  
  def test_initialize_raises_error_for_non_string_or_erb_template
    assert_raises(ArgumentError) { Templater.new nil }
    assert_raises(ArgumentError) { Templater.new 1 }
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
  
  def test_build_sets_filename_if_specified
    t = Templater.new %Q{<% raise 'error!' %>}
    err = assert_raises(RuntimeError) { t.build({}, 'filename') }
    assert_equal 'error!', err.message
    assert err.backtrace[0] =~ /filename:1:in /
  end
  
end
