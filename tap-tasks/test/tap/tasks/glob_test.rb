require File.expand_path('../../../tap_test_helper.rb', __FILE__) 
require 'tap/tasks/glob'

class GlobTest < Test::Unit::TestCase
  include Tap::Tasks
  acts_as_tap_test
  
  attr_reader :g
  
  def setup
    super
    @g = Glob.new
  end
  
  #
  # process test
  #
  
  def test_process_globs_for_files
    class_root.chdir('.', true) do
      assert_equal %w{
        a.txt
        b.txt
        c/a.txt
        c/b.txt
      }, g.process("**/*")
      
      assert_equal %w{
        a.txt
        b.txt
      }, g.process("*")
    end
  end
  
  def test_process_globs_dirs_if_specified
    class_root.chdir('.', true) do
      g.dirs = true
      assert_equal %w{
        a.txt
        b.txt
        c
      }, g.process("*")
    end
  end
  
  def test_process_omits_files_if_specified
    class_root.chdir('.', true) do
      g.dirs = true
      g.files = false
      assert_equal %w{
        c
      }, g.process("*")
    end
  end
  
  def test_process_globs_multiple_patterns
    class_root.chdir('.', true) do
      assert_equal %w{
        c/a.txt
        c/b.txt
        a.txt
      }, g.process("c/*", "a.*")
    end
  end
  
  def test_process_removes_duplicates
    class_root.chdir('.', true) do
      assert_equal %w{
        a.txt
        b.txt
      }, g.process("*", "*")
    end
  end
  
  def test_process_preserves_duplicates_if_specified
    class_root.chdir('.', true) do
      g.unique = false
      assert_equal %w{
        a.txt
        b.txt
        a.txt
        b.txt
      }, g.process("*", "*")
    end
  end
  
  def test_process_filters_by_filters
    class_root.chdir('.', true) do
      g.excludes = [/a/]
      
      assert_equal %w{
        b.txt
        c/b.txt
      }, g.process("**/*")
      
      g.includes = [/c/]
      
      assert_equal %w{
        c/b.txt
      }, g.process("**/*")
    end
  end
end