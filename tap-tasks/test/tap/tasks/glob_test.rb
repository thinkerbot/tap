require File.join(File.dirname(__FILE__), '../../tap_test_helper')
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
    ctr.chdir(:root) do
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
    ctr.chdir(:root) do
      g.dirs = true
      assert_equal %w{
        a.txt
        b.txt
        c
      }, g.process("*")
    end
  end
  
  def test_process_omits_files_if_specified
    ctr.chdir(:root) do
      g.dirs = true
      g.files = false
      assert_equal %w{
        c
      }, g.process("*")
    end
  end
  
  def test_process_globs_multiple_patterns
    ctr.chdir(:root) do
      assert_equal %w{
        c/a.txt
        c/b.txt
        a.txt
      }, g.process("c/*", "a.*")
    end
  end
  
  def test_process_removes_duplicates
    ctr.chdir(:root) do
      assert_equal %w{
        a.txt
        b.txt
      }, g.process("*", "*")
    end
  end
  
  def test_process_preserves_duplicates_if_specified
    ctr.chdir(:root) do
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
    ctr.chdir(:root) do
      g.filters << /a/
      
      assert_equal %w{
        b.txt
        c/b.txt
      }, g.process("**/*")
      
      g.filters << /txt/
      assert_equal %w{
      }, g.process("*")
    end
  end
end