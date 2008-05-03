require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/templater'

class TemplaterTest < Test::Unit::TestCase
  include Tap::Support
  
  def test_documentation
    t = Templater.new( "key: <%= value %>")
    t.value = "default"
    assert_equal "key: default", t.build
  
    t.value = "another"
    assert_equal "key: another", t.build
  end
  
  #
  # build test
  #
  
  def test_build_formats_erb_with_existing_attributes
    t = Templater.new %Q{key: <%= attr %>}, {:attr => 'value'}
    assert_equal "key: value", t.build
  end

end

class TemplaterUtilsTest < Test::Unit::TestCase
  include Tap::Support::Templater::Utils
  
  def test_yamlize_returns_to_yaml_minus_header_and_newline
    assert_equal "key: value", yamlize({'key' => 'value'})
    assert_equal "", yamlize(nil)
    assert_equal "- 1\n- 2\n- 3", yamlize([1, 2, 3])
  end

end