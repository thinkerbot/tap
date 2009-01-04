require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb')
require 'tap/test/generator_test'

class GeneratorTestTest < Test::Unit::TestCase
  include Tap::Test::GeneratorTest
  include Tap::Generator
  
  acts_as_file_test
  
  #
  # build_file test
  #
  
  def test_build_file_returns_content_written_to_io_by_block
    block = lambda {|io| io << "content" }
    assert_equal "content", build_file(block)
  end
  
  def test_build_file_returns_nil_for_nil_block
    assert_equal nil, build_file(nil)
  end
  
  #
  # build_template test
  #
  
  def test_build_template_builds_the_template_with_the_attributes
    template = "<%= key %> was templated"
    assert_equal "value was templated", build_template(template, :key => 'value')
  end
  
  #
  # relative_path test
  #
  
  def test_relative_path_returns_the_path_of_path_relative_to_root
    path = File.expand_path("path/to/file.txt")
    assert_equal "to/file.txt", relative_path(File.expand_path("path"), path)
  end
  
  #
  # assert_actions test
  #
  
  def test_assert_actions_documenation
    template_path = method_root.prepare(:tmp, "template.erb") {|file| file << "<%= key %> was templated"}
  
    actions = []
    m = Manifest.new(actions)
    m.directory '/path/to/dir'
    m.file('/path/to/dir/file.txt') {|io| io << "content"}
    m.template('/path/to/dir/template.txt', template_path, :key => 'value')
  
    builds = assert_actions [
      [:directory, 'dir'],
      [:file, 'dir/file.txt'],
      [:template, 'dir/template.txt']
    ], actions, '/path/to'
  
    assert_equal "content", builds['dir/file.txt']
    assert_equal "value was templated", builds['dir/template.txt']
  end
  
  def test_assert_actions_builds_files_and_templates_and_returns_them_as_a_hash
    template_path = method_root.prepare(:tmp, "template.erb") {|file| file << "<%= key %> was templated"}
  
    actions = []
    m = Manifest.new(actions)
    m.file('/path/to/dir/no_block.txt')
    m.file('/path/to/dir/file.txt') {|io| io << "content"}
    m.template('/path/to/dir/template.txt', template_path, :key => 'value')
  
    builds = assert_actions [
      [:file, 'dir/no_block.txt'],
      [:file, 'dir/file.txt'],
      [:template, 'dir/template.txt']
    ], actions, '/path/to'
    
    assert_equal({
      'dir/no_block.txt' => nil,
      'dir/file.txt' => 'content',
      'dir/template.txt' => "value was templated"
    }, builds)
  end
  
  def test_assert_actions_fails_for_unequal_actions
    actions = []
    m = Manifest.new(actions)
    m.directory '/path/to/dir'
    m.file '/path/to/dir/file.txt'

    e = assert_raise(Test::Unit::AssertionFailedError) do 
      assert_actions([
        [:directory, 'dir'],
        [:template, 'dir/txt.txt']
      ], actions, '/path/to')
    end
    
    assert_equal "unequal action at index: 1.\n<:template> expected but was\n<:file>.", e.message
  end
  
  def test_assert_actions_fails_for_unequal_paths
    actions = []
    m = Manifest.new(actions)
    m.directory '/path/to/dir'
    m.file '/path/to/dir/file.txt'

    e = assert_raise(Test::Unit::AssertionFailedError) do 
      assert_actions([
        [:directory, 'dir'],
        [:file, 'dir/alt.txt']
      ], actions, '/path/to')
    end
    
    assert_equal "unequal path at index: 1.\n<\"dir/alt.txt\"> expected but was\n<\"dir/file.txt\">.", e.message
  end
  
  def test_assert_actions_fails_for_unequal_number_of_expected_and_actual_actions
    actions = []
    m = Manifest.new(actions)
    m.directory '/path/to/dir'
    m.file '/path/to/dir/file.txt'

    e = assert_raise(Test::Unit::AssertionFailedError) { assert_actions([[:directory, 'dir']], actions) }
    assert_equal "unequal number of actions.\n<1> expected but was\n<2>.", e.message
    
    e = assert_raise(Test::Unit::AssertionFailedError) do 
      assert_actions([
        [:directory, 'dir'],
        [:file, 'dir/file.txt'],
        [:file, 'dir/file.rb']
      ], actions)
    end
    assert_equal "unequal number of actions.\n<3> expected but was\n<2>.", e.message
  end
end