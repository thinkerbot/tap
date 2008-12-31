require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb')
require 'tap/generator/destroy'

class DestroyTest < Test::Unit::TestCase
  include Tap::Generator::Destroy
  acts_as_file_test
  
  # this establishes the essential interface provided by Base
  attr_accessor :log, :file_task, :pretend
  
  def setup
    @pretend = false
    @log = []
    @file_task = Tap::FileTask.new
    super
  end
  
  def log_relative(*args)
    log << args
  end
  
  #
  # iterate test
  #
  
  def test_iterate_runs_over_actions_in_reverse
    results = []
    iterate([:a, :b, :c]) {|action| results << action }
    
    assert_equal [:c, :b, :a], results
  end
  
  #
  # directory test
  #
  
  def test_directory_removes_target_and_logs_removal
    target = method_root.filepath(:tmp, 'dir')
    FileUtils.mkdir_p(target) unless File.exists?(target)
    assert File.exists?(target)
    
    directory(target)
    
    assert !File.exists?(target)
    assert File.exists?(method_root.filepath(:tmp))
    assert_equal [[:rm, target]], log
  end
  
  def test_directory_removal_is_only_logged_on_pretend
    target = method_root.filepath(:tmp, 'dir')
    FileUtils.mkdir_p(target) unless File.exists?(target)
    
    self.pretend = true
    directory(target)
    
    assert File.exists?(target)
    assert_equal [[:rm, target]], log
  end
  
  def test_directory_logs_non_existant_targets
    target = method_root.filepath(:tmp, 'dir')
    assert !File.exists?(target)

    directory(target)
    assert_equal [[:missing, target]], log
  end
  
  def test_directory_logs_non_directory_targets
    target = method_root.prepare(:tmp, 'file') {}
    assert File.file?(target)

    directory(target)
    assert File.exists?(target)
    assert_equal [['not a directory', target]], log
  end
  
  def test_directory_logs_non_empty_directories
    file = method_root.prepare(:tmp, 'file') {}
    target = File.dirname(file)

    directory(target)
    assert File.exists?(target)
    assert_equal [['not empty', target]], log
  end
  
  #
  # file test
  #
  
  def test_file_removes_target_and_logs_removal
    target = method_root.prepare(:tmp, 'file') {}
    assert File.file?(target)
    
    file(target)
    
    assert !File.exists?(target)
    assert_equal [[:rm, target]], log
  end
  
  def test_file_removal_is_only_logged_on_pretend
    target = method_root.prepare(:tmp, 'file') {}
    assert File.file?(target)
    
    self.pretend = true
    file(target)
    
    assert File.exists?(target)
    assert_equal [[:rm, target]], log
  end
  
  def test_file_logs_non_existant_targets
    target = method_root.prepare(:tmp, 'file')
    assert !File.exists?(target)

    file(target)
    assert_equal [[:missing, target]], log
  end
  
  def test_file_logs_non_file_targets
    file = method_root.prepare(:tmp, 'file') {}
    target = File.dirname(file)
    assert File.directory?(target)

    file(target)
    assert File.directory?(target)
    assert_equal [['not a file', target]], log
  end
end