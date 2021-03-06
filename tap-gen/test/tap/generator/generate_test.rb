require File.join(File.dirname(__FILE__), '../../test_helper.rb')
require 'tap/generator/generate'
require 'stringio'

class GenerateTest < Test::Unit::TestCase
  include Tap::Generator::Generate
  acts_as_file_test
  
  # this establishes the essential interface provided by Base
  attr_accessor :log, :pretend, :prompt_out, :prompt_in, :skip, :force
  
  def setup
    super
    @pretend = false
    @log = []
    @prompt_out = StringIO.new('')
    @prompt_in = StringIO.new('')
    @skip = false
    @force = false
  end
  
  def path(*paths)
    File.expand_path File.join(*paths)
  end
  
  def log_relative(*args)
    log << args
  end
  
  #
  # directory test
  #

  def test_directory_creates_target_and_logs_activity
    target = method_root.path(:tmp, 'dir')
    assert !File.exists?(target)
    
    directory(target)
    
    assert File.exists?(target)
    assert_equal '40755', sprintf('%o', File.stat(target).mode)
    assert_equal [[:create, target]], log
  end
  
  def test_directory_does_nothing_for_pwd
    pwd = method_root.path(:tmp)
    method_root.chdir(:tmp, true) do 
      directory(pwd)
      assert File.exists?(pwd)
      assert_equal [], log
    end
  end
  
  def test_directory_simply_logs_activity_if_pretend_is_true
    target = method_root.path(:tmp, 'dir')
    assert !File.exists?(target)
    
    self.pretend = true
    directory(target)
    
    assert !File.exists?(target)
    assert_equal [[:create, target]], log
  end
  
  def test_directory_logs_existing_directories
    target = method_root.path(:tmp, 'dir')
    FileUtils.mkdir_p(target) unless File.exists?(target)

    directory(target)
    assert_equal [[:exists, target]], log
  end
  
  #
  # file test
  #
  
  def test_file_creates_target_and_logs_activity
    target = method_root.path(:tmp, 'file.txt')
    assert !File.exists?(target)
    
    file(target)
    
    assert File.exists?(target)
    assert_equal '', File.read(target)
    assert_equal '100644', sprintf('%o', File.stat(target).mode)
    assert_equal [[:create, target]], log
  end
  
  def test_file_creates_target_with_block
    target = method_root.path(:tmp, 'file.txt')
    assert !File.exists?(target)
    
    file(target) do |file|
      file << "content"
    end
    
    assert File.exists?(target)
    assert_equal "content", File.read(target)
    assert_equal [[:create, target]], log
  end
  
  def test_file_does_not_create_target_if_pretend_is_true
    target = method_root.path(:tmp, 'file.txt')
    assert !File.exists?(target)
    
    self.pretend = true
    file(target)
    
    assert !File.exists?(target)
    assert_equal [[:create, target]], log
  end
  
  def test_file_logs_skip_for_identical_content
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "content" }

    file(target) {|file| file << "content" }
    
    assert_equal [[:exists, target]], log
  end
  
  def test_file_forces_collision_if_specified
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    
    self.force = true
    file(target) {|file| file << "new content" }
    
    assert_equal "new content", File.read(target)
    assert_equal [[:force, target]], log
  end
  
  def test_file_does_not_force_collision_if_pretend_is_true
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    
    self.pretend = true
    self.force = true
    file(target) {|file| file << "new content" }
    
    assert_equal "old content", File.read(target)
    assert_equal [[:force, target]], log
  end
  
  def test_file_skips_collision_if_specified
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    
    self.skip = true
    file(target) {|file| file << "new content" }
    
    assert_equal "old content", File.read(target)
    assert_equal [[:skip, target]], log
  end
  
  def test_skip_overrides_force
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    
    self.skip = true
    self.force = true
    file(target) {|file| file << "new content" }
    
    assert_equal "old content", File.read(target)
    assert_equal [[:skip, target]], log
  end
  
  def test_file_prompts_action_for_collision_skips_and_sets_skip_for_i
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    assert_equal false, skip
    
    prompt_in << "i"
    prompt_in.rewind
    file(target) {|file| file << "new content" }
    
    assert_equal true, skip
    assert_equal "overwrite #{target}? [Ynaiq] ", prompt_out.string
    assert_equal "old content", File.read(target)
    assert_equal [[:skip, target]], log
  end
  
  def test_file_prompts_action_for_collision_forces_and_sets_force_for_a
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    assert_equal false, force
    
    prompt_in << "a"
    prompt_in.rewind
    file(target) {|file| file << "new content" }
    
    assert_equal true, force
    assert_equal "overwrite #{target}? [Ynaiq] ", prompt_out.string
    assert_equal "new content", File.read(target)
    assert_equal [[:force, target]], log
  end
  
  def test_file_prompts_action_for_collision_and_skips_for_n
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    
    prompt_in << "n"
    prompt_in.rewind
    file(target) {|file| file << "new content" }
    
    assert_equal "overwrite #{target}? [Ynaiq] ", prompt_out.string
    assert_equal "old content", File.read(target)
    assert_equal [[:skip, target]], log
  end
  
  def test_file_prompts_action_for_collision_and_overwrites_for_y
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    
    prompt_in << "y"
    prompt_in.rewind
    file(target) {|file| file << "new content" }
    
    assert_equal "overwrite #{target}? [Ynaiq] ", prompt_out.string
    assert_equal "new content", File.read(target)
    assert_equal [[:force, target]], log
  end
  
  def test_file_prompts_action_for_collision_and_quits_for_q
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
    
    assert_raises(SystemExit) do    
      prompt_in << "q"
      prompt_in.rewind
      file(target) {|file| file << "new content" }
    end
    
    assert_equal "overwrite #{target}? [Ynaiq] aborting\n", prompt_out.string
    assert_equal "old content", File.read(target)
    assert_equal [], log
  end
  
  def test_file_continues_to_prompt_action_for_unknown_inputs
    target = method_root.prepare(:tmp, 'file.txt') {|file| file << "old content" }
      
    prompt_in.puts "blah"
    prompt_in.puts "blah"
    prompt_in.puts "blah"
    prompt_in.puts "yes"
    prompt_in.rewind
    file(target) {|file| file << "new content" }
    
    assert_equal "overwrite #{target}? [Ynaiq] " * 4, prompt_out.string
    assert_equal "new content", File.read(target)
    assert_equal [[:force, target]], log
  end
end