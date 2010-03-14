require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/templater'

class TemplaterUtilsTest < Test::Unit::TestCase
  include Tap::Templater::Utils
  
  #
  # yamlize test
  #
  
  def test_yamlize_returns_to_yaml_minus_header_and_newline
    assert_equal "key: value", yamlize({'key' => 'value'})
    assert_equal({'key' => 'value'}, YAML.load(yamlize({'key' => 'value'})))
    
    assert_equal "{}", yamlize({})
    assert_equal({}, YAML.load(yamlize({})))
    
    assert_equal "~", yamlize(nil)
    assert_equal nil, YAML.load(yamlize(nil))
    
    assert_equal "- 1\n- 2\n- 3", yamlize([1, 2, 3])
    assert_equal [1, 2, 3], YAML.load(yamlize([1, 2, 3]))
    
    assert_equal "[]", yamlize([])
    assert_equal [], YAML.load(yamlize([]))
    
    assert_equal "|-\nsome\nmultiline\nstring", yamlize("some\nmultiline\nstring")
    assert_equal "some\nmultiline\nstring", YAML.load(yamlize("some\nmultiline\nstring"))
    
    assert_equal '""', yamlize("")
    assert_equal "", YAML.load(yamlize(""))
  end
  
  #
  # nest test
  #
  
  def test_nest_documentation
    result = nest([["\nmodule Some", "end\n"],["module Nested", "end"]]) { "class Const\nend" }
    expected = %Q{
module Some
  module Nested
    class Const
    end
  end
end
}
    
    assert_equal expected, result
  end
  
  def test_nest_nests_content_in_nesting_constant
    content = "multiline\ncontent"
    nested_content = %Q{
module Sample
  module Nest
    multiline
    content
  end
end
}.strip

    assert_equal nested_content, nest([['module Sample', 'end'], ['module Nest', 'end']]) { content }
    assert_equal content, nest([]) { content }
  end
  
  #
  # module_nest test
  #
  
  def test_module_nest_documentation
    result = module_nest('Some::Nested') { "class Const\nend" }
    expected = %Q{
module Some
  module Nested
    class Const
    end
  end
end
}.strip

    assert_equal expected, result
  end
  
  def test_module_nest_nests_content_in_nesting_module
    content = "multiline\ncontent"
    nested_content = %Q{
module Sample
  module Nest
    multiline
    content
  end
end
}.strip

    assert_equal nested_content, module_nest('Sample::Nest') { content }
    assert_equal content, module_nest('') { content }
  end
end