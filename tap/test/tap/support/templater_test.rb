require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/templater'

class TemplaterTest < Test::Unit::TestCase
  include Tap::Support
  acts_as_subset_test
  
  condition(:ruby_1_8) { RUBY_VERSION =~ /^1.8/ }
  condition(:ruby_1_9) { RUBY_VERSION =~ /^1.9/ }
  
  def test_documentation
    t = Templater.new( "key: <%= value %>")
    t.value = "default"
    assert_equal "key: default", t.build
  
    t.value = "another"
    assert_equal "key: another", t.build
    
    e = ERB.new("<%= 1 + 2 %>")
    condition_test(:ruby_1_8) { assert_equal("_erbout = ''; _erbout.concat(( 1 + 2 ).to_s); _erbout", e.src) }
    condition_test(:ruby_1_9) { assert_equal("#coding:US-ASCII\n_erbout = ''; _erbout.concat(( 1 + 2 ).to_s); _erbout", e.src) }
    
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

end

class TemplaterUtilsTest < Test::Unit::TestCase
  include Tap::Support::Templater::Utils
  include Tap::Test::SubsetTest
  
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
  
  def test_nest_speed
    benchmark_test do |x|
      content = "some content\n" * 100
      nesting = [['module Sample', 'end'], ['module Nest', 'end']]
      
      n = 1000
      x.report("#{n}x nest") { n.times { nest(nesting) {content} } }
    end
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