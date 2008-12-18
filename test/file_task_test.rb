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
  
  def test_documentation
    file_one = method_root.filepath(:tmp, "file.txt")
    file_two = method_root.filepath(:tmp, "path/to/file.txt")
    dir = method_root.filepath(:tmp, "some/dir")
    FileUtils.mkdir_p(method_root[:tmp])
    
    File.open(file_one, "w") {|f| f << "original content"}
    t = Tap::FileTask.intern do |task|
      task.mkdir_p(dir)                      
      task.prepare([file_one, file_two]) 
      
      File.open(file_one, "w") {|f| f << "new content"}
      FileUtils.touch(file_two)
  
      raise "error!"
    end
  
    assert !File.exists?(dir)        
    assert !File.exists?(file_two)        
    e = assert_raise(RuntimeError) { t.execute }
    assert_equal "error!", e.message
    assert !File.exists?(dir)        
    assert !File.exists?(file_two) 
    assert_equal "original content", File.read(file_one)  
  end
  
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

    assert_equal File.expand_path("/backup/name/file_20080808.txt"), t.backup_filepath("path/to/file.txt", time)
  end

  def test_backup_filepath_constructs_filepath_from_backup_dir_name_and_input_basename
    t.backup_dir = 'backup_dir'
    t.timestamp = "%Y%m%d"
    t.name = "name"

    assert_equal(app.filepath('backup_dir', "name/file_20080808.txt"), t.backup_filepath("path/to/file.txt", Time.utc(2008,8,8)))
  end

  def test_backup_dir_can_be_full_path
    t.timestamp = "%Y%m%d"
    t.backup_dir = File.expand_path('backup')

    assert_equal(File.expand_path("backup/tap/file_task/file_20080808.txt"), t.backup_filepath("file.txt", Time.utc(2008,8,8)))
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
    t.backup(file)
    backed_up_file = t.backed_up_files[file]
    
    assert !File.exists?(file)                     
    assert File.exists?(backed_up_file)            
    assert_equal "file content", File.read(backed_up_file)         
  
    File.open(file, "w") {|f| f << "new content"}
    t.restore(file, true)
  
    assert File.exists?(file)                
    assert !File.exists?(backed_up_file)      
    assert_equal "file content", File.read(file)                 
  end
  
  def test_backup_moves_file_to_backup_filepath
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = method_root.filepath(:tmp, "backup.txt")
    
    t.extend BackupFile
    t.backup_file = backup_file
    t.backup(existing_file)
  
    assert !File.exists?(existing_file)
    assert File.exists?(backup_file)
    assert_equal "existing content", File.read(backup_file)
  end
  
  def test_backup_copies_file_to_backup_filepath_if_backup_using_copy_is_true
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = method_root.filepath(:tmp, "backup.txt")
    
    t.extend BackupFile
    t.backup_file = backup_file
    t.backup(existing_file, true)
  
    assert File.exists?(existing_file)
    assert File.exists?(backup_file)
    assert FileUtils.compare_file(existing_file, backup_file)
  end
  
  def test_backup_registers_source_and_target_in_backed_up_files
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = method_root.filepath(:tmp, "backup.txt")
    
    assert_equal({}, t.backed_up_files)
    
    t.extend BackupFile
    t.backup_file = backup_file
    t.backup(existing_file)
    
    assert_equal({existing_file => backup_file}, t.backed_up_files)
  end
  
  def test_backup_expands_paths
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    relative_path = Tap::Root.relative_filepath(Dir.pwd, existing_file)
    backup_file = method_root.filepath(:tmp, "backup.txt")
    
    t.extend BackupFile
    t.backup_file = backup_file
    t.backup(relative_path)
  
    assert !File.exists?(existing_file)
    assert File.exists?(backup_file)
    assert_equal({existing_file => backup_file}, t.backed_up_files)
  end
  
  def test_backup_does_nothing_if_file_does_not_exist
    existing_file = method_root.filepath(:tmp, "file.txt")
    backup_file = method_root.filepath(:tmp, "backup.txt")
    
    assert !File.exists?(existing_file)
    assert !File.exists?(backup_file)
    assert_equal({}, t.backed_up_files)
  
    t.extend BackupFile
    t.backup_file = backup_file
    t.backup(existing_file)
  
    assert !File.exists?(existing_file)
    assert !File.exists?(backup_file)
    assert_equal({}, t.backed_up_files)  
  end
  
  def test_backup_raises_error_if_file_is_already_backed_up
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    t.backup(existing_file, true)
  
    e = assert_raise(RuntimeError) { t.backup(existing_file) }
    assert_equal "already backed up: #{existing_file}", e.message
  end
  
  def test_backup_raises_error_if_backup_file_already_exists
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = method_root.prepare(:tmp, "backup.txt") {}
    
    t.extend BackupFile
    t.backup_file = backup_file
    
    e = assert_raise(RuntimeError) { t.backup(existing_file) }
    assert_equal "backup file already exists: #{backup_file}", e.message
  end
  
  def test_backup_acts_on_list
    one = method_root.prepare(:tmp, "one.txt") {|file| file << "one content" }
    two = method_root.prepare(:tmp, "two.txt") {|file| file << "two content" }
  
    t.backup([one, two])
    
    assert !File.exists?(one)
    assert !File.exists?(two)
    
    assert_equal "one content", File.read(t.backed_up_files[one])
    assert_equal "two content", File.read(t.backed_up_files[two])
  end
  
  #
  # restore tests
  #
  
  def test_restore_restores_backed_up_file_to_original_location
    original_file = method_root.filepath(:tmp, 'original/file.txt')
    backup_file = method_root.prepare(:tmp, 'backup/file.txt') {|file| file << "content" }
    
    assert !File.exists?(original_file)
    assert File.exists?(backup_file)
    
    t.backed_up_files[original_file] = backup_file
    t.restore(original_file)
    
    assert File.exists?(original_file)
    assert_equal "content", File.read(original_file)
  end
  
  def test_restore_does_not_remove_backed_up_file
    original_file = method_root.filepath(:tmp, 'original/file.txt')
    backup_file = method_root.prepare(:tmp, 'backup/file.txt') {|file| file << "content" }
    
    t.backed_up_files[original_file] = backup_file
    t.restore(original_file)
    
    assert_equal({original_file => backup_file}, t.backed_up_files)
    assert File.exists?(backup_file)
    assert_equal "content", File.read(backup_file)
  end
  
  def test_restore_removes_backed_up_file_if_specified_and_cleans_up_backup_dir
    original_file = method_root.filepath(:tmp, 'original/file.txt')
    backup_file = method_root.prepare(:tmp, 'path/to/backup/file.txt') {|file| file << "content" }
    
    t.backed_up_files[original_file] = backup_file
    t.restore(original_file, true)
    
    assert_equal({}, t.backed_up_files)
    assert !File.exists?(backup_file)
    assert !File.exists?(method_root.filepath(:tmp, 'path'))
    assert File.exists?(method_root.filepath(:tmp))
  end
  
  def test_restore_does_nothing_if_the_input_file_is_not_backed_up
    assert !File.exists?("original_file")
    assert t.backed_up_files.empty?
    
    t.restore("original_file")
    
    assert !File.exists?("original_file")
  end
  
  def test_restore_acts_on_list
    one = method_root.filepath(:tmp, "one.txt")
    two = method_root.filepath(:tmp, "two.txt")
    backup_one = method_root.prepare(:tmp, "backup_one.txt") {|file| file << "one content"}
    backup_two = method_root.prepare(:tmp, "backup_two.txt") {|file| file << "two content"}
  
    t.backed_up_files[one] = backup_one
    t.backed_up_files[two] = backup_two
  
    assert !File.exists?(one)
    assert !File.exists?(two)
  
    t.restore([one, two])
  
    assert File.exists?(one)
    assert File.exists?(two)
    
    assert_equal "one content", File.read(one)
    assert_equal "two content", File.read(two)
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
  
  def test_mkdir_p_registers_all_added_dirs_in_added_files
    dir = method_root.filepath(:tmp, 'path/to/dir')
    assert_equal [], t.added_files
  
    t.mkdir_p(dir)
  
    expected = [
      method_root.root,
      method_root.filepath(:tmp),
      method_root.filepath(:tmp, 'path'),
      method_root.filepath(:tmp, 'path/to'),
      method_root.filepath(:tmp, 'path/to/dir')
    ]
    assert_equal expected, t.added_files
  end
  
  #
  # mkdir tests
  #
  
  def test_mkdir_creates_dir_if_it_does_not_exist
    FileUtils.mkdir_p(method_root[:tmp])
    dir = method_root.filepath(:tmp, 'dir')
    assert !File.exists?(dir)
  
    t.mkdir(dir)
    assert File.exists?(dir)
  end
  
  def test_mkdir_registers_added_dir_in_added_files
    FileUtils.mkdir_p(method_root[:tmp])
    dir = method_root.filepath(:tmp, 'dir')
    assert_equal [], t.added_files
  
    t.mkdir(dir)
  
    assert_equal [method_root.filepath(:tmp, 'dir')], t.added_files
  end

  def test_mkdir_acts_on_list_of_dirs
    FileUtils.mkdir_p(method_root[:tmp])
    one = method_root.filepath(:tmp, 'one')
    two = method_root.filepath(:tmp, 'two')
  
    assert !File.exists?(one)
    assert !File.exists?(two)
  
    t.mkdir([one, two])
  
    assert File.exists?(one)
    assert File.exists?(two)
  end
  
  def test_mkdir_correctly_adds_mixed_up_paths
    FileUtils.mkdir_p(method_root.root)
    
    t.mkdir([
      Tap::Root.relative_filepath(Dir.pwd, method_root.filepath(:tmp, 'path')),
      method_root.filepath(:tmp, 'path/to/one'),
      method_root.filepath(:tmp),
      method_root.filepath(:tmp, 'path/to')
    ])
    
    assert File.exists?(method_root.filepath(:tmp, 'path/to/one'))
  end
  
  #
  # prepare tests
  #
  
  def test_prepare_documentation
    file_one = method_root.filepath(:tmp, "file.txt")
    file_two = method_root.filepath(:tmp, "path/to/file.txt")
    FileUtils.mkdir_p( method_root[:tmp] )
  
    File.open(file_one, "w") {|f| f << "original content"}
    t = Tap::FileTask.intern do |task|
      assert !File.exists?(method_root.filepath(:tmp, "path"))
  
      # backup... prepare parent dirs... prepare for restore     
      task.prepare([file_one, file_two]) 
  
      File.open(file_one, "w") {|f| f << "new content"}
      FileUtils.touch(file_two)
  
      raise "error!"
    end
  
    e = assert_raise(RuntimeError) { t.execute }
    assert_equal "error!", e.message
    assert File.exists?(file_one)           
    assert_equal "original content", File.read(file_one) 
    assert !File.exists?(method_root.filepath(:output, "path"))   
  end
  
  def test_prepare_backs_up_existing_files
    file = method_root.prepare(:tmp, "file.txt") {|file| file << "content" }

    t.prepare(file) 

    assert !File.exists?(file)
    assert File.exists?(File.dirname(file))
    assert t.backed_up_files.has_key?(file)
    assert_equal "content", File.read(t.backed_up_files[file])
  end
  
  def test_prepare_creates_parent_dir_for_non_existant_dirs
    file = method_root.filepath(:tmp, "path/to/file.txt")
    assert !File.exists?(File.dirname(file))
    
    t.prepare(file) 

    assert !File.exists?(file)
    assert File.exists?(File.dirname(file))
  end
  
  def test_prepare_adds_added_dirs_and_paths_to_added_files
    file = method_root.filepath(:tmp, "path/to/file.txt")
    assert !File.exists?(method_root[:tmp])
    
    t.prepare(file) 

    expected = [
      method_root.root,                            # added by mkdir
      method_root[:tmp],                           # added by mkdir
      method_root.filepath(:tmp, 'path'),          # added by mkdir
      method_root.filepath(:tmp, 'path/to'),       # added by mkdir
      file                                         # added by prepare
    ]
    assert_equal expected, t.added_files
  end
  
  def test_prepare_does_not_add_existing_files_to_added_files
    file = method_root.prepare(:tmp, "existing_file.txt") {}
    
    t.prepare(file) 
    
    expected = [
      method_root[:backup],                             # added by backup.mkdir
      method_root.filepath(:backup, 'tap'),             # added by backup.mkdir
      method_root.filepath(:backup, 'tap/file_task')    # added by backup.mkdir
    ]
    assert_equal expected, t.added_files
  end
  
  def test_prepare_acts_on_list
    one = method_root.filepath(:tmp, "one")
    two = method_root.filepath(:tmp, "path/to/two")
    
    t.prepare([one, two])
    
    assert File.exists?(File.dirname(one))
    assert File.exists?(File.dirname(two))
  end
  
  #
  # rmdir tests
  #
  
  def test_rmdir_removes_dir
    dir = method_root.filepath(:tmp, 'path/to/dir')
    FileUtils.mkdir_p(dir)

    t.rmdir(dir)
    assert !File.exists?(dir)
  end
  
  def test_rmdir_backs_up_dir
    dir = method_root.filepath(:tmp, 'path/to/dir')
    FileUtils.mkdir_p(dir)

    t.rmdir(dir)
    assert !File.exists?(dir)
    assert t.backed_up_files.has_key?(dir)
    assert File.directory?(t.backed_up_files[dir])
    assert Tap::Root.empty?(t.backed_up_files[dir])
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
  
  def test_rmdir_acts_on_list_of_dirs
    one = method_root.filepath(:tmp, 'one')
    two = method_root.filepath(:tmp, 'two')
    FileUtils.mkdir_p(one)
    FileUtils.mkdir_p(two)
  
    t.rmdir([one, two])
    
    assert !File.exists?(one)
    assert !File.exists?(two)
  end
  
  def test_rmdir_correctly_removes_mixed_up_paths
    one = method_root.filepath(:tmp, 'path/to/one')
    FileUtils.mkdir_p(one)
    
    t.rmdir([
      Tap::Root.relative_filepath(Dir.pwd, method_root.filepath(:tmp, 'path')),
      method_root.filepath(:tmp, 'path/to/one'),
      method_root.filepath(:tmp),
      method_root.filepath(:tmp, 'path/to')
    ])
    
    assert !File.exists?(method_root[:tmp])
  end
  
  #
  # rm tests
  #
  
  def test_rm_removes_file
    path = method_root.prepare(:tmp, 'path/to/file.txt') {}
    
    t.rm(path)
    
    assert !File.exists?(path)
  end
  
  def test_rm_backs_up_file
    path = method_root.prepare(:tmp, 'path/to/file.txt') {|file| file << "content" }
    
    t.rm(path)
    
    assert !File.exists?(path)
    assert t.backed_up_files.has_key?(path)
    assert_equal "content", File.read(t.backed_up_files[path])
  end
  
  def test_rm_does_not_backup_a_file_twice
    path = method_root.prepare(:tmp, 'path/to/file.txt') {|file| file << "content" }
    t.rm(path)
    
    Tap::Root.prepare(path) {|file| file << "new content" }
    t.rm(path)
    
    assert !File.exists?(path)
    assert t.backed_up_files.has_key?(path)
    assert_equal "content", File.read(t.backed_up_files[path])
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
  
  def test_rm_acts_on_list_of_files
    one = method_root.prepare(:tmp, 'one') {}
    two = method_root.prepare(:tmp, 'two') {}

    t.rm([one, two])
    
    assert !File.exists?(one)
    assert !File.exists?(two)
  end
  
  #
  # rollback test
  #
  
  def test_rollback_restores_backed_up_files_and_clears_added_files
    backup_file = method_root.prepare(:backup, 'backup.txt') {|file| file << "backup content" }
    current_file = method_root.prepare(:tmp, 'current.txt') {|file| file << "overridden content" }
    added_file = method_root.prepare(:tmp, 'added.txt') {}
    added_dir = FileUtils.mkdir_p method_root.filepath(:tmp, 'dir')
    
    t.backed_up_files[current_file] = backup_file
    t.added_files.concat [added_file, added_dir]
    
    t.rollback
    
    assert !File.exists?(backup_file)
    assert File.exists?(current_file)
    assert_equal "backup content", File.read(current_file)
    assert !File.exists?(added_file)
    assert !File.exists?(added_dir)
    
    assert t.backed_up_files.empty?
    assert t.added_files.empty?
  end

  #
  # execute tests
  #
  
  def setup_execute_test(&block)
    existing_file = method_root.prepare(:tmp, "existing_file.txt") {|file| file << "original content" }
    non_existant_dir = method_root.filepath(:tmp, "non_existing_dir")
    non_existant_file = method_root.filepath(:tmp, "non_existing_dir/non_existing_file.txt")
    backup_file = method_root.filepath(:tmp, "backup/file.txt")
  
    @t = Tap::FileTask.intern do |task|
      task.prepare([existing_file, non_existant_file])
      block.call if block_given?
    end
    
    # assure the backup goes where expected
    t.extend BackupFile
    t.backup_file = backup_file
  
    [existing_file, backup_file, non_existant_dir, non_existant_file]
  end
  
  def test_setup_execute_test
    existing_file, backup_file, non_existant_dir, non_existant_file = setup_execute_test do 
      assert !File.exists?(non_existant_file)
      assert File.exists?(non_existant_dir)
      assert File.exists?(backup_file)
      assert_equal "original content", File.read(backup_file)
    end
    t.execute
  end
  
  def test_execute_restores_backups_and_removes_added_files_on_error
    was_in_execute = false
    existing_file, backup_file, non_existant_dir, non_existant_file = setup_execute_test do 
      was_in_execute = true
      raise "error"
    end
  
    assert_raise(RuntimeError) { t.execute  }
  
    # check the existing file was restored
    assert was_in_execute
    assert File.exists?(existing_file)
    assert !File.exists?(non_existant_dir)
    assert !File.exists?(backup_file)
    assert_equal "original content", File.read(existing_file)
    assert t.added_files.empty?
    assert t.backed_up_files.empty?
  end
  
  def test_execute_does_not_restore_backups_if_rollback_on_error_is_false
    was_in_execute = false
    existing_file, backup_file, non_existant_dir, non_existant_file = setup_execute_test do
      was_in_execute = true
      raise "error"
    end
  
    t.rollback_on_error = false
    assert_raise(RuntimeError) { t.execute  }
  
    # check the existing file was NOT restored
    assert was_in_execute
    assert !File.exists?(existing_file)
    assert File.exists?(non_existant_dir)
    assert File.exists?(backup_file)
    assert_equal "original content", File.read(backup_file)
    assert !t.added_files.empty?
    assert !t.backed_up_files.empty?
  end
  
  def test_execute_does_not_rollback_results_from_prior_executions
    existing_file = method_root.prepare(:tmp, "existing_file.txt") {|file| file << "original content" }
    non_existant_dir = method_root.filepath(:tmp, "non_existing_dir")
    non_existant_file = method_root.filepath(:tmp, "non_existing_dir/non_existing_file.txt")
    backup_file = method_root.filepath(:tmp, "backup/file.txt")
    
    count = 0
    @t = Tap::FileTask.intern do |task|
      if count > 0
        count = 2
        raise "error" 
      else
        count = 1
        task.prepare([existing_file, non_existant_file]) 
        method_root.prepare(:tmp, "existing_file.txt") {|file| file << "new content" }
      end
    end
  
    # assure the backup goes where expected
    t.extend BackupFile
    t.backup_file = backup_file
  
    assert_nothing_raised { t.execute }
    assert_equal 1, count
    assert File.exists?(existing_file)
    assert_equal "new content", File.read(existing_file)   
    assert File.exists?(non_existant_dir)
    assert File.exists?(backup_file)
    assert_equal "original content", File.read(backup_file)   
  
    assert_raise(RuntimeError) { t.execute }
  
    # check the existing file was NOT restored
    assert_equal 2, count
    assert File.exists?(existing_file)
    assert_equal "new content", File.read(existing_file)   
    assert File.exists?(non_existant_dir)
    assert File.exists?(backup_file)
    assert_equal "original content", File.read(backup_file)   
  end
  
  #
  # test execute with multiple files
  #
  
  def setup_multiple_file_execute_test(&block)
    existing_files = [0,1].collect do |n|
      method_root.prepare(:output, "path/to/existing/file#{n}.txt") {|file| file << n.to_s }
    end
    
    backup_files = existing_files.collect do |file|
      method_root.filepath(:output, File.basename(file) + "_backup")
    end
  
    non_existant_files =  [0,1].collect do |n|
      method_root.filepath(:output, "path/to/non/existing/file#{n}.txt")
    end
  
    @t = Tap::FileTask.intern do |task|
      task.prepare(existing_files + non_existant_files) 
      block.call if block_given?
    end
    
    # assure the backup goes where expected
    t.extend BackupFile
    t.backup_file = backup_files
  
    [existing_files, non_existant_files]
  end
  
  def test_setup_multiple_file_execute_test
    existing_files, non_existant_files = setup_multiple_file_execute_test do 
      (existing_files + existing_files).each do |file|
        assert !File.exists?(file)
        assert File.exists?(File.dirname(file))
      end
    end
    t.execute
  end
  
  def test_execute_restore_and_removal_with_multiple_files
    was_in_execute = false
    existing_files, non_existant_files = setup_multiple_file_execute_test do
      was_in_execute = true
      (existing_files + non_existant_files) .each do |file|
        method_root.prepare(file) {|f| f << "new content" }
      end
      raise "error"
    end
  
    assert !File.exists?(method_root.filepath(:output, 'backup'))
    assert_raise(RuntimeError) { t.execute }
  
    # check existing files were restored, made files and backups removed.
    assert was_in_execute
    existing_files.each_with_index do |existing_file, n|
      assert File.exists?(existing_file)
      assert_equal n.to_s, File.read(existing_file)
    end
    non_existant_files.each do |non_existing_file|
      assert !File.exists?(non_existing_file)
    end
    assert !File.exists?(method_root.filepath(:output, 'backup'))
  end
  
end
