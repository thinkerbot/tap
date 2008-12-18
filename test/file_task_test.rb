require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/file_task'

class FileTaskTest < Test::Unit::TestCase
  acts_as_tap_test 
  cleanup_dirs << :backup
  
  attr_reader :t

  def setup
    super
    @t = Tap::FileTask.new
    app.root = method_root.root
  end
  
  # simple overrides to backup file to provide a
  # pre-defined backup file.
  module BackupFile
    attr_accessor :backup_file
    
    def backup_filepath(*args)
      backup_file
    end
  end
  
  #
  # doc tests
  #
  
  # def test_documentation
  #   file_one = method_root.filepath(:tmp, "file.txt")
  #   file_two = method_root.filepath(:tmp, "path/to/file.txt")
  #   dir = method_root.filepath(:tmp, "some/dir")
  #   FileUtils.mkdir_p(method_root[:tmp])
  #   
  #   File.open(file_one, "w") {|f| f << "original content"}
  #   t = Tap::FileTask.intern do |task|
  #     task.mkdir_p(dir)                      
  #     task.prepare([file_one, file_two]) 
  #     
  #     File.open(file_one, "w") {|f| f << "new content"}
  #     FileUtils.touch(file_two)
  # 
  #     raise "error!"
  #   end
  # 
  #   assert !File.exists?(dir)        
  #   assert !File.exists?(file_two)        
  #   e = assert_raise(RuntimeError) { t.execute }
  #   assert_equal "error!", e.message
  #   assert !File.exists?(dir)        
  #   assert !File.exists?(file_two) 
  #   assert_equal "original content", File.read(file_one)  
  # end
  
  #
  # basepath test
  #
  
  def test_basepath_doc
    assert_equal 'path/to/file', t.basepath('path/to/file.txt')
    assert_equal 'path/to/file.html', t.basepath('path/to/file.txt', '.html')
    
    assert_equal 'path/to/file',  t.basepath('path/to/file.txt', false)
    assert_equal 'path/to/file.txt',  t.basepath('path/to/file.txt', true)
  end
  
  def test_basepath_with_false_or_nil_extname_chomps_extname
    assert_equal 'path/to/file',  t.basepath('path/to/file.txt', false)
    assert_equal 'path/to/file',  t.basepath('path/to/file.txt', nil)
  end
  
  def test_basepath_with_true_extname_does_nothing
    assert_equal 'path/to/file.txt',  t.basepath('path/to/file.txt', true)
  end
  
  def test_basepath_can_exchange_extname_in_dot_or_no_dot_format
    assert_equal 'path/to/file.html',  t.basepath('path/to/file.txt', ".html")
    assert_equal 'path/to/file.html',  t.basepath('path/to/file.txt', "html")
  end

  #
  # basename test
  #

  def test_basename_doc
    assert_equal 'file.txt', t.basename('path/to/file.txt')
    assert_equal 'file.html', t.basename('path/to/file.txt', '.html')
    
    assert_equal 'file',  t.basename('path/to/file.txt', false)
    assert_equal 'file.txt',  t.basename('path/to/file.txt', true)
  end

  #
  # filepath tests
  #

  def test_filepath_doc
    t = Tap::FileTask.new 
    t.app[:data, true] = "/data" 
    assert_equal "tap/file_task", t.name
    assert_equal File.expand_path("/data/tap/file_task/result.txt"), t.filepath(:data, "result.txt")
  end

  def test_filepath_constructs_path_using_app_filepath_and_name
    assert_equal "tap/file_task", t.name
    assert_equal(
    app.filepath(:dir, "tap/file_task", "path", "to", "file"),
    t.filepath(:dir, "path", "to", "file"))
  end

  #
  # backup_filepath test
  #

  def test_backup_filepath_documentation
    t = Tap::FileTask.new({:timestamp => "%Y%m%d"}, 'name')
    t.app['backup', true] = "/backup"
    time = Time.utc(2008,8,8)

    assert_equal File.expand_path("/backup/name/file_20080808_0.txt"), t.backup_filepath("path/to/file.txt", time)
  end

  def test_backup_filepath_constructs_filepath_from_backup_dir_name_and_input_basename
    t.backup_dir = 'backup_dir'
    t.timestamp = "%Y%m%d"
    t.name = "name"

    assert_equal(app.filepath('backup_dir', "name/file_20080808_0.txt"), t.backup_filepath("path/to/file.txt", Time.utc(2008,8,8)))
  end

  def test_backup_dir_can_be_full_path
    t.timestamp = "%Y%m%d"
    t.backup_dir = File.expand_path('backup')

    assert_equal(File.expand_path("backup/tap/file_task/file_20080808_0.txt"), t.backup_filepath("file.txt", Time.utc(2008,8,8)))
  end

  #
  # uptodate tests
  #

  def uptodate_test_setup
    of1 = ctr.filepath(:root, 'old_file_one.txt')
    of2 = ctr.filepath(:root, 'old_file_two.txt')

    nf1 = method_root.prepare(:tmp, 'new_file_one.txt') {}
    nf2 = method_root.prepare(:tmp, 'new_file_two.txt') {}

    [of1, of2, nf1, nf2]
  end

  def test_uptodate_test_setup
    files = uptodate_test_setup
    files.each { |file| assert File.exists?(file), file }

    of1, of2, nf1, nf2 = files
    assert FileUtils.uptodate?(nf1, [of1])
    assert FileUtils.uptodate?(nf2, [of1])
    assert FileUtils.uptodate?(nf1, [of2])
    assert FileUtils.uptodate?(nf2, [of2])
  end

  def test_uptodate
    of1, of2, nf1, nf2 = uptodate_test_setup

    non = ctr.filepath(:tmp, "non_existant_file.txt")
    assert !File.exists?(non)

    assert t.uptodate?(nf1)
    assert t.uptodate?(nf1, of1)
    assert t.uptodate?(nf1, [of1, of2])
    assert t.uptodate?(nf1, [of1, of2, non])
    assert t.uptodate?([nf1, nf2], of1)
    assert t.uptodate?([nf1, nf2], [of1, of2])

    assert !t.uptodate?(of1, nf1)
    assert !t.uptodate?(of1, [nf1, nf2])
    assert !t.uptodate?(non, nf1)
    assert !t.uptodate?(non, of1)
    assert !t.uptodate?([nf1, non], of1)
    assert !t.uptodate?([nf1, non], [of1, of2])
  end

  def test_uptodate_returns_false_when_force
    of1, of2, nf1, nf2 = uptodate_test_setup

    assert t.uptodate?(nf1, of1)
    with_config :force => true do
      assert app.force
      assert !t.uptodate?(nf1, of1)
    end
  end

  # 
  # backup tests
  #
  
  def test_backup_restore_doc
    FileUtils.mkdir_p(method_root[:tmp])
  
    file = method_root.filepath(:tmp, "file.txt")
    File.open(file, "w") {|f| f << "file content"}
  
    t = Tap::FileTask.new
    t.app[:backup, true] = method_root.filepath(:backup)
    backup_file = t.backup(file)
    
    assert !File.exists?(file)                     
    assert File.exists?(backup_file)            
    assert_equal "file content", File.read(backup_file)         
  
    File.open(file, "w") {|f| f << "new content"}
    t.rollback
  
    assert File.exists?(file)                
    assert !File.exists?(backup_file)      
    assert_equal "file content", File.read(file)                 
  end
   
  def test_backup_moves_file_to_backup_file_and_returns_backup_file
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = t.backup(existing_file)
  
    assert !File.exists?(existing_file)
    assert File.exists?(backup_file)
    assert_equal "existing content", File.read(backup_file)
  end
  
  def test_backup_copies_file_to_backup_file_if_backup_using_copy_is_true
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = t.backup(existing_file, true)
  
    assert File.exists?(existing_file)
    assert File.exists?(backup_file)
    assert FileUtils.compare_file(existing_file, backup_file)
  end
  
  def test_backup_may_be_rolled_back
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = t.backup(existing_file)
    t.rollback
    
    assert !File.exists?(backup_file)
    assert File.exists?(existing_file)
    assert_equal "existing content", File.read(existing_file)
  end
  
  def test_backup_does_nothing_if_file_does_not_exist
    existing_file = method_root.filepath(:tmp, "file.txt")
    assert_equal nil, t.backup(existing_file)
    assert !File.exists?(existing_file)
  end
  
  def test_backup_raises_error_if_backup_file_already_exists
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = method_root.prepare(:tmp, "backup.txt") {}
    
    t.extend BackupFile
    t.backup_file = backup_file
    
    e = assert_raise(RuntimeError) { t.backup(existing_file) }
    assert_equal "backup file already exists: #{backup_file}", e.message
  end
  
  #
  # mkdir_p tests
  #
  
  def test_mkdir_p_creates_dir_and_parent_dirs_if_they_do_not_exist
    dir = method_root.filepath(:tmp, 'path/to/dir')
    assert !File.exists?(method_root[:tmp])
  
    t.mkdir_p(dir)
    assert File.exists?(dir)
  end
  
  def test_mkdir_p_may_be_rolled_back
    dir = method_root.filepath(:tmp, 'path/to/dir')
    assert !File.exists?(method_root[:tmp])
    
    t.mkdir_p(dir)
    assert File.exists?(dir)
    
    t.rollback
    assert !File.exists?(method_root[:tmp])
  end
  
  #
  # mkdir tests
  #
  
  def test_mkdir_creates_dir_if_it_does_not_exist
    assert !File.exists?(method_root.root)
    
    t.mkdir(method_root.root)
    assert File.exists?(method_root.root)
  end
  
  def test_mkdir_may_be_rolled_back
    assert !File.exists?(method_root.root)
    
    t.mkdir(method_root.root)
    assert File.exists?(method_root.root)
    
    t.rollback
    assert !File.exists?(method_root.root)
  end
  
  #
  # prepare tests
  #
  
  def test_prepare_documentation
    file_one = method_root.filepath(:tmp, "file.txt")
    FileUtils.mkdir_p(method_root[:tmp])
  
    File.open(file_one, "w") {|f| f << "original content"}
    t = Tap::FileTask.intern do |task|   
      task.prepare(file_one) {|f| f << "new content"}
      assert_equal "new content", File.read(file_one)
      
      raise "error!"
    end
  
    e = assert_raise(RuntimeError) { t.execute }
    assert_equal "error!", e.message
    assert File.exists?(file_one)           
    assert_equal "original content", File.read(file_one) 
    assert !File.exists?(method_root.filepath(:output, "path"))   
  end
  
  def test_prepare_removes_existing_file
    path = method_root.prepare(:tmp, "file.txt") {|file| file << "content" }
    
    t.prepare(path)
    
    assert !File.exists?(path)
    assert File.exists?(File.dirname(path))
  end
  
  def test_prepare_creates_parent_dir_for_non_existant_dirs
    path = method_root.filepath(:tmp, "path/to/file.txt")
    assert !File.exists?(method_root[:tmp])
    
    t.prepare(path)
    
    assert !File.exists?(path)
    assert File.exists?(File.dirname(path))
  end
  
  def test_prepare_yields_open_file_to_block_if_given
    path = method_root.filepath(:tmp, "file.txt")
    
    t.prepare(path) {|file| file << "content"}
    assert_equal "content", File.read(path)
  end
  
  def test_prepare_may_be_rolled_back
    path = method_root.prepare(:tmp, "file.txt") {|file| file << "content" }
    
    t.prepare(path) {|file| file << "new content"}
    assert_equal "new content", File.read(path)
    
    t.rollback
    assert_equal "content", File.read(path)
  end
  
  def test_prepare_rolls_back_created_dirs
    path = method_root.filepath(:tmp, "path/to/file.txt")
    assert !File.exists?(method_root[:tmp])
    
    t.prepare(path) {}
    assert File.exists?(path)
    
    t.rollback
    assert !File.exists?(method_root[:tmp])
  end
  
  #
  # rmdir tests
  #
  
  def test_rmdir_removes_dir
    dir = method_root.filepath(:tmp, 'path/to/dir')
    FileUtils.mkdir_p(dir)
  
    t.rmdir(dir)
    assert !File.exists?(dir)
    assert File.exists?(File.dirname(dir))
  end
  
  def test_rmdir_may_be_rolled_back
    dir = method_root.filepath(:tmp, 'path/to/dir')
    FileUtils.mkdir_p(dir)
  
    t.rmdir(dir)
    assert !File.exists?(dir)
    
    t.rollback
    assert File.exists?(dir)
  end
  
  def test_rmdir_raises_error_if_input_is_not_an_empty_directory
    file = method_root.prepare(:tmp, 'path/to/file.txt') {}
  
    e = assert_raise(RuntimeError) { t.rmdir(file) }
    assert_equal "not an empty directory: #{file}", e.message
    
    dir = File.dirname(file)
    
    e = assert_raise(RuntimeError) { t.rmdir(dir) }
    assert_equal "not an empty directory: #{dir}", e.message
    
    assert File.exists?(file)
  end

  #
  # rm tests
  #
  
  def test_rm_removes_file
    path = method_root.prepare(:tmp, 'path/to/file.txt') {}
    
    t.rm(path)
    
    assert !File.exists?(path)
    assert File.exists?(File.dirname(path))
  end
  
  def test_rm_may_be_rolled_back
    path = method_root.prepare(:tmp, 'path/to/file.txt') {|file| file << "content" }
    
    t.rm(path)
    assert !File.exists?(path)
    
    t.rollback
    assert File.exists?(path)
    assert_equal "content", File.read(path)
  end
  
  def test_rmdir_raises_error_if_input_is_not_an_existing_file
    path = method_root.filepath(:tmp, 'path/to/file.txt')
  
    e = assert_raise(RuntimeError) { t.rm(path) }
    assert_equal "not a file: #{path}", e.message
    
    FileUtils.mkdir_p(path)
    
    e = assert_raise(RuntimeError) { t.rm(path) }
    assert_equal "not a file: #{path}", e.message
    
    assert File.directory?(path)
  end
  
  #
  # rollback test
  #
  
  def test_rollback_for_multiple_changes_to_same_paths
    a = method_root.filepath(:tmp, 'a')
    b = method_root.filepath(:tmp, 'a/b')
    c = method_root.prepare(:tmp, 'a/b/c.txt') {|file| file << "c content" }
    d = method_root.prepare(:tmp, 'a/b/d.txt') {|file| file << "d content" }
    
    t.rm(c)
    t.rm_r(b)
    t.mkdir(b)
    
    assert !File.exists?(c)
    assert !File.exists?(d)
    
    t.rmdir(b)
    t.prepare(d) {|file| file << "new d content" }
    
    assert !File.exists?(c)
    assert_equal "new d content", File.read(d)
    
    t.rm_r(a)
    t.prepare(c) {|file| file << "new c content" }
    
    assert_equal "new c content", File.read(c)
    assert !File.exists?(d)

    t.rollback
    
    assert_equal "c content", File.read(c)
    assert_equal "d content", File.read(d)
  end
  
  #
  # execute tests
  #
  
  def test_execute_rolls_back_on_error
    existing_file = method_root.prepare(:tmp, "existing_file.txt") {|file| file << "original content" }
    non_existant_file = method_root.filepath(:tmp, "non_existing_file.txt")
    non_existant_dir = method_root.filepath(:tmp, "path/to/dir")
    
    was_in_execute = false
    t = Tap::FileTask.intern do |task|
      task.prepare(existing_file) {|file| file << "new content" }
      task.prepare(non_existant_file) {|file| file << "content" }
      task.mkdir_p(non_existant_dir)
      
      assert_equal "new content", File.read(existing_file)
      assert_equal "content", File.read(non_existant_file)
      assert File.exists?(non_existant_dir)
      
      was_in_execute = true
      raise "error"
    end
    
    e = assert_raise(RuntimeError) { t.execute }
    assert_equal "error", e.message
    
    assert was_in_execute
    assert File.exists?(existing_file)
    assert_equal "original content", File.read(existing_file)
    
    assert !File.exists?(non_existant_file)
    assert !File.exists?(non_existant_dir)
  end
  
  def test_execute_does_not_roll_back_if_rollback_on_error_is_false
    existing_file = method_root.prepare(:tmp, "existing_file.txt") {|file| file << "original content" }
    non_existant_file = method_root.filepath(:tmp, "non_existing_file.txt")
    non_existant_dir = method_root.filepath(:tmp, "path/to/dir")
    
    was_in_execute = false
    t = Tap::FileTask.intern(:rollback_on_error => false) do |task|
      task.prepare(existing_file) {|file| file << "new content" }
      task.prepare(non_existant_file) {|file| file << "content" }
      task.mkdir_p(non_existant_dir)
      
      was_in_execute = true
      raise "error"
    end
    
    e = assert_raise(RuntimeError) { t.execute }
    assert_equal "error", e.message
    
    assert was_in_execute
    assert_equal "new content", File.read(existing_file)
    assert_equal "content", File.read(non_existant_file)
    assert File.exists?(non_existant_dir)
  end
  
  def test_execute_does_not_rollback_results_from_prior_executions
    path = method_root.filepath(:tmp, "file.txt")
    
    t = Tap::FileTask.intern do |task, raise_error|
      task.prepare(path) do |file| 
        file << "raise error was: #{raise_error}"
      end
      raise "error" if raise_error
    end
    
    t.execute(false)
    
    assert_equal "raise error was: false", File.read(path)
    
    e = assert_raise(RuntimeError) { t.execute(true) }
    assert_equal "error", e.message
    
    assert_equal "raise error was: false", File.read(path)
  end
  
end
