require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb')
require 'tap/generator/base'

class BaseTest < Test::Unit::TestCase
  include Tap::Generator
  acts_as_tap_test
  
  attr_accessor :b
  
  def setup
    super
    @b = Base.new
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    b = Base.new
    assert_equal File.expand_path("templates/tap/generator/base"), b.template_dir
  end
  
  #
  # process test
  #
  
  module MockIterate
    def manifest(m, *argv)
    end
    def iterate(actions)
      "results"
    end
    def directory(target, options={})
    end
    def file(target, options={})
    end
  end
  
  def test_process_returns_iterate_results
    b.extend MockIterate
    assert_equal "results", b.process
  end
  
  #
  # manifest test
  #
  
  def test_manifest_raises_not_implemented_error
    assert_raises(NotImplementedError) { b.manifest(:m) }
  end
  
  #
  # iterate test
  #
  
  def test_iterate_runs_over_actions_in_order
    results = []
    b.iterate([:a, :b, :c]) {|action| results << action }
    
    assert_equal [:a, :b, :c], results
  end
  
  def test_iterate_collects_block_results
    results = b.iterate([:a, :b, :c]) {|action| action }
    assert_equal [:a, :b, :c], results
  end
  
  #
  # directory test
  #
  
  def test_directory_raises_not_implemented_error
    assert_raises(NotImplementedError) { b.directory(:target) }
  end
  
  #
  # file test
  #
  
  def test_file_raises_not_implemented_error
    assert_raises(NotImplementedError) { b.file(:target) }
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
  
  def test_directories_returns_collected_results_of_directory_calls
    d = Directories.new
    
    # dumb test but it is what it is.
    r = d.directory_calls
    assert_equal [r,r,r,r], d.directories('root', ['a', 'b', 'c'])
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
    source = method_root.prepare(:tmp, 'source') do |file|
      file << "<%= key %> was templated"
    end
    
    t = Template.new
    t.template_dir = method_root.root
    
    t.template('target', source, {:key => 'value'}, {:opt => 'value'})
    assert_equal [['target', {:opt => 'value'}], "value was templated"], t.file_call
    
    relative_source = method_root.relative_path(:root, source)
    t.template('target', relative_source, {:key => 'value'}, {:opt => 'value'})
    assert_equal [['target', {:opt => 'value'}], "value was templated"], t.file_call
  end
  
  def test_template_raises_error_if_no_template_dir_is_set
    b.template_dir = nil
    err = assert_raises(RuntimeError) { b.template('target', 'source') }
    assert_equal "no template dir is set", err.message
  end
  
  #
  # template_files test
  #
  
  def test_template_files_yields_templates_and_targets
    a = method_root.prepare(:tmp, 'a') {}
    b = method_root.prepare(:tmp, 'b') {}
    c = method_root.prepare(:tmp, 'c/a') {} 

    base = Base.new
    base.template_dir = method_root[:tmp]
    
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
  
  def test_template_files_returns_targets
    a = method_root.prepare(:tmp, 'a') {}
    b = method_root.prepare(:tmp, 'b') {}
    c = method_root.prepare(:tmp, 'c/a') {} 

    base = Base.new
    base.template_dir = method_root[:tmp]
    
    assert_equal ['a', 'b', 'c/a'], base.template_files {|s,t| }
  end
  
  def test_template_files_raises_error_if_no_template_dir_is_set
    b.template_dir = nil
    err = assert_raises(RuntimeError) { b.template_files {} }
    assert_equal "no template dir is set", err.message
  end
  
  #
  # on test
  #
  
  module Action
    attr_accessor :action
  end
  
  def test_on_calls_block_if_actions_include_action
    b.extend Action
    b.action = :test
    
    was_in_block = false
    b.on(:test) { was_in_block = true }
    assert_equal true,  was_in_block
    
    was_in_block = false
    b.on(:a, :test, :b) { was_in_block = true }
    assert_equal true,  was_in_block
    
    was_in_block = false
    b.on(:a, :b) { was_in_block = true }
    assert_equal false, was_in_block
  end
  
  def test_on_returns_block_return_if_called_and_nil_otherwise
    b.extend Action
    b.action = :test
    
    assert_equal :result, b.on(:test) { :result }
    assert_equal nil, b.on(:not_called) { :result }
  end
  
  #
  # action test
  #
  
  def test_action_raises_not_implemented_error
    assert_raises(NotImplementedError) { b.action }
  end
end