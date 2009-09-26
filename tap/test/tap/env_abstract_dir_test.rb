require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/env'
require 'tap/test'

class EnvAbstractDirTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_file_test :cleanup_dirs => [:root]
  
  Env = Tap::Env
  
  attr_accessor :a, :b, :c, :d
  
  def setup
    super
    
    @a, @b, @c, @d = %w{a b c d}.collect do |letter|
      Env.new(path(letter))
    end

    a.push b
    b.push c
    a.push d
  end
  
  def path(input)
    method_root.path(input)
  end
  
  #
  # glob test
  #
  
  def test_glob_returns_matching_files_in_the_abstract_dir
    assert_equal [], a.glob(:root)
    
    a.root.prepare('one.txt') {}
    assert_equal [path('a/one.txt')], a.glob(:root)
    
    d.root.prepare('two.txt') {}
    assert_equal [path('a/one.txt'), path('d/two.txt')], a.glob(:root)
    assert_equal [path('d/two.txt')], a.glob(:root, "two.txt")
    assert_equal [path('a/one.txt'), path('d/two.txt')], a.glob(:root, "*.txt")
    
    assert_equal [], b.glob(:root)
    assert_equal [path('d/two.txt')], d.glob(:root)
  end
  
  def test_glob_returns_first_matches_for_identical_relative_paths
    b.root.prepare('path/to/one.txt') {}
    c.root.prepare('path/to/one.txt') {}
    d.root.prepare('path/to/one.txt') {}
    
    assert_equal [path('b/path/to/one.txt')], a.glob(:root, "**/*.txt")
    assert_equal [path('b/path/to/one.txt')], b.glob(:root, "**/*.txt")
    assert_equal [path('c/path/to/one.txt')], c.glob(:root, "**/*.txt")
    assert_equal [path('d/path/to/one.txt')], d.glob(:root, "**/*.txt")
  end
  
  #
  # path test
  #
  
  def test_path_returns_the_path_satisfying_block_in_abstract_dir
    assert_equal nil, a.path(:root, 'one.txt') {|path| File.exists?(path) }
    
    dpath = d.root.prepare('one.txt') {}
    assert_equal dpath, a.path(:root, 'one.txt') {|path| File.exists?(path) }
    
    cpath = c.root.prepare('one.txt') {}
    assert_equal cpath, a.path(:root, 'one.txt') {|path| File.exists?(path) }
    
    apath = a.root.prepare('one.txt') {}
    assert_equal apath, a.path(:root, 'one.txt') {|path| File.exists?(path) }
    assert_equal nil, a.path(:root, 'one.txt') {|path| false }
  end
  
  def test_path_returns_the_path_for_root_if_no_block_is_given
    assert_equal path('a/one.txt'), a.path(:root, 'one.txt')
    assert_equal path('d/one.txt'), d.path(:root, 'one.txt')
  end
  
  #
  # class_path test
  #
  
  class Classpath
  end
  
  def test_class_path_returns_path_for_obj_class
    assert_equal path("a/dir/object"), a.class_path(:dir, Object.new)
    assert_equal path("a/dir/object/path"), a.class_path(:dir, Object.new, "path")
    assert_equal path("a/dir/env_abstract_dir_test/classpath/path"), a.class_path(:dir, Classpath.new, "path")
    assert_equal path("d/dir/env_abstract_dir_test/classpath/path"), d.class_path(:dir, Classpath.new, "path")
  end
  
  def test_class_path_seeks_up_env_and_class_hierarchy_while_block_returns_false
    paths = []
    a.class_path(:dir, Classpath.new, "path") {|path| paths << path; false }
  
    assert_equal [
      path("a/dir/env_abstract_dir_test/classpath/path"),
      path("b/dir/env_abstract_dir_test/classpath/path"),
      path("c/dir/env_abstract_dir_test/classpath/path"),
      path("d/dir/env_abstract_dir_test/classpath/path"),
      path("a/dir/object/path"),
      path("b/dir/object/path"),
      path("c/dir/object/path"),
      path("d/dir/object/path")
    ], paths
  end
  
  def test_class_path_stops_seeking_when_block_returns_true
    assert_equal nil, a.class_path(:dir, Object.new, "path") {|path| File.exists?(path) }
    assert_equal nil, a.class_path(:dir, Classpath.new, "path") {|path| File.exists?(path) }
    
    cpath = c.root.prepare('dir/object/path') {}
    assert_equal cpath, a.class_path(:dir, Object.new, "path") {|path| File.exists?(path) }
    assert_equal cpath, a.class_path(:dir, Classpath.new, "path") {|path| File.exists?(path) }
    
    bpath = b.root.prepare('dir/env_abstract_dir_test/classpath/path') {}
    assert_equal cpath, a.class_path(:dir, Object.new, "path") {|path| File.exists?(path) }
    assert_equal bpath, a.class_path(:dir, Classpath.new, "path") {|path| File.exists?(path) }
  end
  
  def test_class_path_returns_nil_if_block_never_returns_true
    assert_equal nil, a.class_path(:dir, Object.new, "path") {|path| false }
    assert_equal nil, a.class_path(:dir, Classpath.new, "path") {|path| false }
  end
  
  class ClassWithModulePath
    def self.module_path
      "alt"
    end
  end
  
  def test_class_path_uses_class_module_path_if_specified
    assert_equal path("a/dir/alt/path"), a.class_path(:dir, ClassWithModulePath.new, "path")
  end
end