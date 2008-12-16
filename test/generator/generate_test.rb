require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/generator/generate'

class GenerateTest < Test::Unit::TestCase
  include Tap::Generator::Generate
  acts_as_file_test
  
  # this establishes the essential interface provided by Base
  attr_accessor :log, :file_task, :pretend
  
  def setup
    @pretend = false
    @log = []
    @file_task = Tap::FileTask.new
    super
  end
  
  def cleanup
    Tap::Test::Utils.clear_dir(method_root.root)
  end
  
  def log_relative(*args)
    log << args
  end
  
  #
  # iterate test
  #
  
  def test_iterate_runs_over_actions_in_order
    results = []
    iterate([:a, :b, :c]) {|action| results << action }
    
    assert_equal [:a, :b, :c], results
  end
  
  #
  # directory test
  #

  def test_directory_creates_target_and_logs_activity
    target = method_root.filepath(:output, 'dir')
    assert !File.exists?(target)
    
    directory(target)
    
    assert File.exists?(target)
    assert_equal [[:create, target]], log
  end
  
  def test_directory_simply_logs_activity_if_pretend_is_true
    target = method_root.filepath(:output, 'dir')
    assert !File.exists?(target)
    
    self.pretend = true
    directory(target)
    
    assert !File.exists?(target)
    assert_equal [[:create, target]], log
  end
  
  def test_directory_logs_existing_directories
    target = method_root.filepath(:output, 'dir')
    FileUtils.mkdir_p(target) unless File.exists?(target)

    directory(target)
    assert_equal [[:exists, target]], log
  end
  
  #
  # file test
  #
  
  def test_file_creates_target_and_logs_activity
    target = method_root.filepath(:output, 'file.txt')
    assert !File.exists?(target)
    
    file(target)
    
    assert File.exists?(target)
    assert_equal "", File.read(target)
    assert_equal [[:create, target]], log
  end
  
  def test_file_creates_target_with_block
    target = method_root.filepath(:output, 'file.txt')
    assert !File.exists?(target)
    
    file(target) do |file|
      file << "content"
    end
    
    assert File.exists?(target)
    assert_equal "content", File.read(target)
    assert_equal [[:create, target]], log
  end
  
end