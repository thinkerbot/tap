require 'test/unit'
require 'fileutils'

class MtimeCheck < Test::Unit::TestCase
  
  def root
    File.expand_path "#{File.dirname(__FILE__)}/mtime"
  end
  
  def path
    File.join(root, "path")
  end
  
  def sub_dir
    File.join(root, "dir")
  end
  
  def sub_dir_path
    File.join(sub_dir, "path")
  end
  
  def teardown
    FileUtils.rm_r(root) if File.exists?(root)
  end
  
  #
  # no mtime change tests
  #
  
  def test_reading_a_file_does_not_change_file_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(path)
    
    sleep 1
    
    File.read(path)
    assert_equal mtime, File.mtime(path)
  end
  
  def test_opening_a_file_in_some_modes_does_not_change_file_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(path)
    
    sleep 1
    
    File.open(path, "r") {|file| }
    File.open(path, "a") {|file| }
    File.open(path, "r+") {|file| }
    
    assert_equal mtime, File.mtime(path)
  end
  
  def test_reading_a_file_in_a_dir_does_not_change_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(root)
    
    sleep 1
    
    File.read(path)
    assert_equal mtime, File.mtime(root)
  end
  
  def test_opening_a_file_in_a_dir_does_not_change_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(root)
    
    sleep 1
    
    File.open(path, "r") {|file| }
    File.open(path, "w") {|file| }
    File.open(path, "a") {|file| }
    File.open(path, "w+") {|file| }
    
    assert_equal mtime, File.mtime(root)
  end
  
  def test_changing_a_file_in_a_dir_does_not_change_dir_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(root)

    sleep 1
    
    File.open(path, "w") {|file| file << "content" }
    assert_equal mtime, File.mtime(root)
  end
  
  def test_adding_a_file_to_a_sub_dir_does_not_change_dir_mtime
    FileUtils.mkdir(root)
    FileUtils.mkdir(sub_dir)
    mtime = File.mtime(root)
    
    sleep 1
    
    FileUtils.touch(sub_dir_path)
    assert_equal mtime, File.mtime(root)
  end
  
  def test_removing_a_file_from_a_sub_dir_does_not_change_dir_mtime
    FileUtils.mkdir(root)
    FileUtils.mkdir(sub_dir)
    FileUtils.touch(sub_dir_path)
    mtime = File.mtime(root)
    
    sleep 1
    
    FileUtils.rm(sub_dir_path)
    assert_equal mtime, File.mtime(root)
  end
  
  #
  # mtime change tests
  #
  
  def test_changing_a_file_changes_file_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(path)
    
    sleep 1
    
    File.open(path, "r+") {|file| file << 'content' }
    assert_not_equal mtime, File.mtime(path)
    assert mtime < File.mtime(path)
  end
  
  def test_opening_a_file_in_write_mode_changes_file_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(path)
    
    sleep 1
    
    File.open(path, "w") {|file| }
    assert_not_equal mtime, File.mtime(path)
    assert mtime < File.mtime(path)
  end
  
  def test_adding_a_file_to_a_dir_changes_dir_mtime
    FileUtils.mkdir(root)
    mtime = File.mtime(root)
    
    sleep 1
    
    FileUtils.touch(path)
    assert_not_equal mtime, File.mtime(root)
    assert mtime < File.mtime(root)
  end
  
  def test_removing_a_file_from_a_dir_changes_dir_mtime
    FileUtils.mkdir(root)
    FileUtils.touch(path)
    mtime = File.mtime(root)
    
    sleep 1
    
    FileUtils.rm(path)
    assert_not_equal mtime, File.mtime(root)
    assert mtime < File.mtime(root)
  end
end