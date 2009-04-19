require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/tasks/file_task'

class FileTaskTest < Test::Unit::TestCase
  include MethodRoot
  include AppInstance
  
  attr_reader :t
  
  @@ctr = Tap::Root.new("#{__FILE__.chomp("_test.rb")}")
  def ctr
    @@ctr
  end
  
  def setup
    super
    @t = Tap::FileTask.new
    @t.backup_dir = method_root[:backup]
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
    path = method_root.prepare(:tmp, "file.txt") {|file| file << "original content"}
    dir = method_root.prepare(:tmp, "some/dir")
    
    t = Tap::FileTask.intern(:backup_dir => method_root[:backup]) do |task, raise_error|
      task.mkdir_p(dir)              # marked for rollback
      task.prepare(path) do |file|    # marked for rollback
        file << "new content"
      end
  
      # raise an error to start rollback
      raise "error!" if raise_error
    end
  
    e = assert_raises(RuntimeError) { app.execute(t, true) }
    assert_equal "error!", e.message
    assert_equal false, File.exists?(dir)
    assert_equal "original content", File.read(path)
    
    app.execute(t, false)
    assert_equal true, File.exists?(dir)
    assert_equal "new content", File.read(path)
  end
  
  #
  # initialize_copy test
  #
  
  def test_duplicates_do_not_rollback_one_another
    path = method_root.prepare(:tmp, "file.txt") {|file| file << "content"}
    
    t.backup(path)
    assert !File.exists?(path)
    
    t.dup.rollback
    assert !File.exists?(path)
    
    t.rollback
    assert_equal "content", File.read(path)
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
    assert_equal "tap/file_task", t.name
    assert_equal File.expand_path("data/tap/file_task/result.txt"), t.filepath('data', "result.txt")
  end
  
  #
  # backup_filepath test
  #
  
  def test_backup_filepath_documentation
    backup = File.expand_path("/backup")
    t = Tap::FileTask.new({:backup_dir => backup}, "name")
    assert_equal File.join(backup, "name/file.0.txt"), t.backup_filepath("path/to/file.txt")
  end
  
  def test_backup_filepath_constructs_filepath_from_backup_dir_name_and_input_basename
    t.backup_dir = 'backup_dir'
    t.name = "name"
  
    assert_equal File.expand_path('backup_dir/name/file.0.txt'), t.backup_filepath("path/to/file.txt")
  end
  
  def test_backup_dir_can_be_full_path
    t.backup_dir = File.expand_path('backup')
    assert_equal File.expand_path("backup/tap/file_task/file.0.txt"), t.backup_filepath("file.txt")
  end
  
  def test_backup_filepath_increments_index_to_next_non_existant_file
    method_root.prepare(:backup, 'tap/file_task/file.0.txt') {}
    method_root.prepare(:backup, 'tap/file_task/file.1.txt') {}
    assert_equal method_root.path(:backup, 'tap/file_task/file.2.txt'), t.backup_filepath("file.txt")
  end
   
  #
  # uptodate tests
  #
  
  def uptodate_test_setup
    of1 = ctr.path(:root, 'old_file_one.txt')
    of2 = ctr.path(:root, 'old_file_two.txt')
  
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
  
    non = ctr.path(:tmp, "non_existant_file.txt")
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
  
  def test_uptodate_returns_false_when_force_is_true
    of1, of2, nf1, nf2 = uptodate_test_setup
  
    assert t.uptodate?(nf1, of1)
    app.force = true
    assert !t.uptodate?(nf1, of1)
  end
  
  # 
  # backup tests
  #
  
  def test_backup_restore_doc
    FileUtils.mkdir_p(method_root[:tmp])
  
    file = method_root.path(:tmp, "file.txt")
    File.open(file, "w") {|f| f << "file content"}
  
    t = Tap::FileTask.new(:backup_dir => method_root[:backup])
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
    existing_file = method_root.path(:tmp, "file.txt")
    assert_equal nil, t.backup(existing_file)
    assert !File.exists?(existing_file)
  end
  
  def test_backup_raises_error_if_backup_file_already_exists
    existing_file = method_root.prepare(:tmp, "file.txt") {|file| file << "existing content" }
    backup_file = method_root.prepare(:tmp, "backup.txt") {}
    
    t.extend BackupFile
    t.backup_file = backup_file
    
    e = assert_raises(RuntimeError) { t.backup(existing_file) }
    assert_equal "backup already exists: #{backup_file}", e.message
  end
  
  #
  # mkdir_p tests
  #
  
  def test_mkdir_p_creates_dir_and_parent_dirs_if_they_do_not_exist
    dir = method_root.path(:tmp, 'path/to/dir')
    assert !File.exists?(method_root[:tmp])
  
    t.mkdir_p(dir)
    assert File.exists?(dir)
  end
  
  def test_mkdir_p_may_be_rolled_back
    dir = method_root.path(:tmp, 'path/to/dir')
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
  
  def test_prepare_removes_existing_file
    path = method_root.prepare(:tmp, "file.txt") {|file| file << "content" }
    
    t.prepare(path)
    
    assert !File.exists?(path)
    assert File.exists?(File.dirname(path))
  end
  
  def test_prepare_creates_parent_dir_for_non_existant_dirs
    path = method_root.path(:tmp, "path/to/file.txt")
    assert !File.exists?(method_root[:tmp])
    
    t.prepare(path)
    
    assert !File.exists?(path)
    assert File.exists?(File.dirname(path))
  end
  
  def test_prepare_yields_open_file_to_block_if_given
    path = method_root.path(:tmp, "file.txt")
    
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
    path = method_root.path(:tmp, "path/to/file.txt")
    assert !File.exists?(method_root[:tmp])
    
    t.prepare(path) {}
    assert File.exists?(path)
    
    t.rollback
    assert !File.exists?(method_root[:tmp])
  end
  
  #
  # rm_r tests
  #
  
  def test_rm_r_removes_file
    path = method_root.prepare(:tmp, 'path/to/file.txt') {}
    
    t.rm_r(path)
    
    assert !File.exists?(path)
    assert File.exists?(File.dirname(path))
  end
  
  def test_rm_r_removes_dir_recusively
    path = method_root.prepare(:tmp, 'path/to/file.txt') {}
    dir = method_root.path(:tmp, 'path')
  
    t.rm_r(dir)
    assert !File.exists?(dir)
    assert File.exists?(method_root[:tmp])
  end
  
  def test_rm_r_may_be_rolled_back
    one = method_root.prepare(:tmp, 'path/to/one.txt') {|file| file << "one content" }
    two = method_root.prepare(:tmp, 'dir/to/file.txt') {|file| file << "two content" }
    
    t.rm_r(one)
    t.rm_r(method_root.path(:tmp, 'dir'))
    assert !File.exists?(method_root.path(:tmp, 'dir'))
    assert !File.exists?(one)
    assert File.exists?(method_root.path(:tmp, 'path/to'))
    
    t.rollback
    assert_equal "one content", File.read(one)
    assert_equal "two content", File.read(two)
  end
  
  #
  # rmdir tests
  #
  
  def test_rmdir_removes_dir
    dir = method_root.path(:tmp, 'path/to/dir')
    FileUtils.mkdir_p(dir)
  
    t.rmdir(dir)
    assert !File.exists?(dir)
    assert File.exists?(File.dirname(dir))
  end
  
  def test_rmdir_may_be_rolled_back
    dir = method_root.path(:tmp, 'path/to/dir')
    FileUtils.mkdir_p(dir)
  
    t.rmdir(dir)
    assert !File.exists?(dir)
    
    t.rollback
    assert File.exists?(dir)
  end
  
  def test_rmdir_raises_error_if_input_is_not_an_empty_directory
    file = method_root.prepare(:tmp, 'path/to/file.txt') {}
  
    e = assert_raises(RuntimeError) { t.rmdir(file) }
    assert_equal "not an empty directory: #{file}", e.message
    
    dir = File.dirname(file)
    
    e = assert_raises(RuntimeError) { t.rmdir(dir) }
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
    path = method_root.path(:tmp, 'path/to/file.txt')
  
    e = assert_raises(RuntimeError) { t.rm(path) }
    assert_equal "not a file: #{path}", e.message
    
    FileUtils.mkdir_p(path)
    
    e = assert_raises(RuntimeError) { t.rm(path) }
    assert_equal "not a file: #{path}", e.message
    
    assert File.directory?(path)
  end
  
  #
  # cp tests
  #
  
  def test_cp_copies_source_to_target
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target/file.txt')
    
    t.cp(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target)
  end
  
  def test_cp_copies_source_to_target_source_if_target_is_a_directory
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target')
    FileUtils.mkdir(target)
    
    t.cp(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target + "/file.txt")
  end
  
  def test_cp_may_be_rolled_back
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target/file.txt')
    
    t.cp(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target)
    
    t.rollback
    
    assert_equal "content", File.read(source)
    assert !File.exists?(target)
    assert !File.exists?(File.dirname(target))
  end
  
  def test_cp_with_target_dir_may_be_rolled_back
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target')
    FileUtils.mkdir(target)
    
    t.cp(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target + "/file.txt")
    
    t.rollback
    
    assert_equal "content", File.read(source)
    assert File.exists?(target)
    assert !File.exists?(target + "/file.txt")
  end
  
  #
  # cp_r tests
  #
  
  def test_cp_r_copies_source_to_target
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target/file.txt')
    
    t.cp_r(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target)
  end
  
  def test_cp_r_recursively_copies_source_dir_to_target
    one = method_root.prepare(:tmp, 'source/one.txt') {|file| file << "one content" }
    two = method_root.prepare(:tmp, 'source/one/two.txt') {|file| file << "two content" }
    source = File.dirname(one)
    target = method_root.path(:tmp, 'target')
    
    t.cp_r(source, target)
    
    assert_equal "one content", File.read(one)
    assert_equal "one content", File.read(method_root.path(:tmp, 'target/one.txt'))
    assert_equal "two content", File.read(two)
    assert_equal "two content", File.read(method_root.path(:tmp, 'target/one/two.txt'))
  end
  
  def test_cp_r_copies_source_to_target_source_if_target_is_a_directory
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target')
    FileUtils.mkdir(target)
    
    t.cp_r(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target + "/file.txt")
  end
  
  def test_cp_r_may_be_rolled_back
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target/file.txt')
    
    t.cp_r(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target)
    
    t.rollback
    
    assert_equal "content", File.read(source)
    assert !File.exists?(target)
    assert !File.exists?(File.dirname(target))
  end
  
  def test_cp_r_with_source_dir_may_be_rolled_back
    one = method_root.prepare(:tmp, 'source/one.txt') {|file| file << "one content" }
    two = method_root.prepare(:tmp, 'source/one/two.txt') {|file| file << "two content" }
    source = File.dirname(one)
    target = method_root.path(:tmp, 'target')
  
    t.cp_r(source, target)
  
    assert_equal "one content", File.read(one)
    assert_equal "one content", File.read(method_root.path(:tmp, 'target/one.txt'))
    assert_equal "two content", File.read(two)
    assert_equal "two content", File.read(method_root.path(:tmp, 'target/one/two.txt'))
    
    t.rollback
    
    assert_equal "one content", File.read(one)
    assert_equal "two content", File.read(two)
    assert !File.exists?(target)
    assert File.exists?(File.dirname(target))
  end
  
  def test_cp_r_with_target_dir_may_be_rolled_back
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target')
    FileUtils.mkdir(target)
    
    t.cp_r(source, target)
    
    assert_equal "content", File.read(source)
    assert_equal "content", File.read(target + "/file.txt")
    
    t.rollback
    
    assert_equal "content", File.read(source)
    assert File.exists?(target)
    assert !File.exists?(target + "/file.txt")
  end
  
  #
  # mv tests
  #
  
  def test_mv_moves_source_to_target
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target/file.txt')
    
    t.mv(source, target)
    
    assert !File.exists?(source)
    assert File.exists?(File.dirname(source))
    assert_equal "content", File.read(target)
  end
  
  def test_mv_may_be_rolled_back
    source = method_root.prepare(:tmp, 'source/file.txt') {|file| file << "content" }
    target = method_root.path(:tmp, 'target/file.txt')
    
    t.mv(source, target)
    
    assert !File.exists?(source)
    assert_equal "content", File.read(target)
    
    t.rollback
    
    assert_equal "content", File.read(source)
    assert !File.exists?(target)
    assert !File.exists?(File.dirname(target))
  end
  
  #
  # rollback test
  #
  
  def test_rollback_for_multiple_changes_to_same_paths
    a = method_root.path(:tmp, 'a')
    b = method_root.path(:tmp, 'a/b')
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
  
  def test_rollback_for_backups_chasing_a_backup_file
    a = method_root.prepare(:tmp, 'path/to/a') {|file| file << "content" }
    
    b = t.backup(a)
    c = t.backup(b)
    
    FileUtils.rm_r(method_root[:tmp])
    File.open(b, 'w') {|file| file << "new content"}
    
    t.rollback
    
    assert !File.exists?(c)
    assert !File.exists?(b)
    assert_equal "content", File.read(a)
  end
  
  #
  # cleanup tests
  #
  
  def test_cleanup_removes_backup_files_and_cleans_up_dirs
    a = method_root.prepare(:tmp, 'path/to/a') {|file| file << "content" }
    b = t.backup(a)
    File.open(a, "w") {|file| file << "new content" }
    
    assert_equal "content", File.read(b)
    assert_equal 0, b.index(method_root[:backup])
    
    t.cleanup
    
    assert !File.exists?(b)
    assert !File.exists?(method_root[:backup])
    assert_equal "new content", File.read(a)
  end
  
  def test_cleanup_ignores_made_files_and_dirs
    a = method_root.path(:tmp, 'path/to/a')
    b = method_root.path(:tmp, 'some/dir')
    
    t.prepare(a) {|file| file << "content" }
    t.mkdir_p(b)
    t.cleanup
    
    assert_equal "content", File.read(a)
    assert File.exists?(b)
  end
  
  def test_cleanup_does_not_cleanup_dirs_unless_specified
    a = method_root.prepare(:tmp, 'path/to/a') {|file| file << "content" }
    b = t.backup(a)
    
    t.cleanup(false)
    
    assert !File.exists?(b)
    assert File.exists?(File.dirname(b))
  end
  
  def test_cleanup_prevents_rollback
    a = method_root.prepare(:tmp, 'path/to/a') {|file| file << "content" }
    b = t.backup(a)
    File.open(a, "w") {|file| file << "new content" }
    
    t.cleanup
    t.rollback
  
    assert_equal "new content", File.read(a)
  end
  
  #
  # cleanup_dir tests
  #
  
  def test_cleanup_dir_removes_all_dir_and_empty_parent_dirs
    dir = method_root.path(:tmp, 'path/to/dir')
    FileUtils.mkdir_p(dir)
    
    path = method_root.prepare(:tmp, 'path/file.txt') {}
    
    t.cleanup_dir(dir)
    
    assert !File.exists?(dir)
    assert !File.exists?(method_root.path(:tmp, 'path/to'))
    assert File.exists?(method_root.path(:tmp, 'path'))
  end
  
  #
  # execute tests
  #
  
  def test_execute_rolls_back_on_error
    existing_file = method_root.prepare(:tmp, "existing_file.txt") {|file| file << "original content" }
    non_existant_file = method_root.path(:tmp, "non_existing_file.txt")
    non_existant_dir = method_root.path(:tmp, "path/to/dir")
    
    was_in_execute = false
    t = Tap::FileTask.intern(:backup_dir => method_root[:backup]) do |task|
      task.prepare(existing_file) {|file| file << "new content" }
      task.prepare(non_existant_file) {|file| file << "content" }
      task.mkdir_p(non_existant_dir)
      
      assert_equal "new content", File.read(existing_file)
      assert_equal "content", File.read(non_existant_file)
      assert File.exists?(non_existant_dir)
      
      was_in_execute = true
      raise "error"
    end
    
    e = assert_raises(RuntimeError) { app.execute(t) }
    assert_equal "error", e.message
    
    assert was_in_execute
    assert File.exists?(existing_file)
    assert_equal "original content", File.read(existing_file)
    
    assert !File.exists?(non_existant_file)
    assert !File.exists?(non_existant_dir)
  end
  
  def test_execute_does_not_roll_back_if_rollback_on_error_is_false
    existing_file = method_root.prepare(:tmp, "existing_file.txt") {|file| file << "original content" }
    non_existant_file = method_root.path(:tmp, "non_existing_file.txt")
    non_existant_dir = method_root.path(:tmp, "path/to/dir")
    
    was_in_execute = false
    t = Tap::FileTask.intern(:backup_dir => method_root[:backup], :rollback_on_error => false) do |task|
      task.prepare(existing_file) {|file| file << "new content" }
      task.prepare(non_existant_file) {|file| file << "content" }
      task.mkdir_p(non_existant_dir)
      
      was_in_execute = true
      raise "error"
    end
    
    e = assert_raises(RuntimeError) { app.execute(t) }
    assert_equal "error", e.message
    
    assert was_in_execute
    assert_equal "new content", File.read(existing_file)
    assert_equal "content", File.read(non_existant_file)
    assert File.exists?(non_existant_dir)
  end
  
  def test_execute_does_not_rollback_results_from_prior_executions
    path = method_root.path(:tmp, "file.txt")
    
    t = Tap::FileTask.intern(:backup_dir => method_root[:backup]) do |task, raise_error|
      task.prepare(path) do |file| 
        file << "raise error was: #{raise_error}"
      end
      raise "error" if raise_error
    end
    
    app.execute(t, false)
    
    assert_equal "raise error was: false", File.read(path)
    
    e = assert_raises(RuntimeError) { app.execute(t, true) }
    assert_equal "error", e.message
    
    assert_equal "raise error was: false", File.read(path)
  end
end
