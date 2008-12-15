require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/generator/base'

class BaseTest < Test::Unit::TestCase
  include Tap::Generator
  acts_as_file_test
  
  attr_accessor :b
  
  def setup
    @b = Base.new
    super
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    b = Base.new
    assert_equal File.expand_path("#{Base.source_file}/../templates"), b.template_dir
  end
  
  #
  # manifest test
  #
  
  def test_manifest_raises_not_implemented_error
    assert_raise(NotImplementedError) { b.manifest(:m) }
  end
  
  #
  # iterate test
  #
  
  def test_iterate_raises_not_implemented_error
    assert_raise(NotImplementedError) { b.iterate([]) }
  end
  
  #
  # directory test
  #
  
  def test_directory_raises_not_implemented_error
    assert_raise(NotImplementedError) { b.directory(:target) }
  end
  
  #
  # file test
  #
  
  def test_file_raises_not_implemented_error
    assert_raise(NotImplementedError) { b.file(:target) }
  end
  
  #
  # directories test
  #
  
  class Directories < Base
    def directory_calls
      @directory_calls ||= []
    end
    def directory(*args)
      directory_calls << args
    end
  end
  
  def test_directories_calls_directory_with_root_and_each_target_relative_to_root
    d = Directories.new
    d.directories('root', ['a', 'b', 'c'], {:opt => 'value'})
    assert_equal [
      ['root', {:opt => 'value'}],
      ['root/a', {:opt => 'value'}],
      ['root/b', {:opt => 'value'}],
      ['root/c', {:opt => 'value'}],
    ], d.directory_calls
  end
  
  #
  # template test
  #
  
  class Template < Base
    def file_call
      @file_call
    end
    def file(*args)
      @file_call = [args, yield("")]
    end
  end
  
  def test_template_calls_file_with_target_and_prints_source_templated_with_args
    source = method_tempfile('source') do |file|
      file << "<%= key %> was templated"
    end
    
    t = Template.new
    t.template_dir = method_root.root
    
    t.template('target', source, {:key => 'value'}, {:opt => 'value'})
    assert_equal [['target', {:opt => 'value'}], "value was templated"], t.file_call
    
    relative_source = method_root.relative_filepath(:root, source)
    t.template('target', relative_source, {:key => 'value'}, {:opt => 'value'})
    assert_equal [['target', {:opt => 'value'}], "value was templated"], t.file_call
  end
  
  #
  # template_files test
  #
  
  def test_template_files_yields_templates_and_targets
    a = method_root.filepath(:output, 'a') 
    b = method_root.filepath(:output, 'b') 
    c = method_root.filepath(:output, 'c/a') 
    
    FileUtils.mkdir_p(File.dirname(c))
    FileUtils.touch(a)
    FileUtils.touch(b)
    FileUtils.touch(c)
    
    base = Base.new
    base.template_dir = method_root[:output]
    
    results = []
    base.template_files do |src, target|
      results << [src, target]
    end
    
    assert_equal [
      [a, 'a'],
      [b, 'b'],
      [c, 'c/a']
    ], results
  end
end