require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/file_task'

class FileTaskTest < Test::Unit::TestCase
  acts_as_tap_test 

  attr_reader :t

  def setup
    super
    @t = Tap::FileTask.new
    app.root = ctr.root
  end

  def touch_file(path, content=nil)
    FileUtils.mkdir_p(File.dirname(path))
    if content
      File.open(path, "w") {|f| f << content}
    else
      FileUtils.touch(path)
    end
  end

  def test_touch_file
    non_existant_file = method_root.filepath(:output, "non_existant_file.txt")
    assert !File.exists?(non_existant_file)
    touch_file(non_existant_file)
    assert File.exists?(non_existant_file)
    assert File.file?(non_existant_file)
    assert_equal "", File.read(non_existant_file)

    non_existant_file = method_root.filepath(:output, "non_existant_file2.txt")
    assert !File.exists?(non_existant_file)
    touch_file(non_existant_file, "content")
    assert File.exists?(non_existant_file)
    assert File.file?(non_existant_file)
    assert_equal "content", File.read(non_existant_file)
  end
  
  module BackupFile
    attr_accessor :backup_file
    
    def backup_filepath(*args)
      backup_file.kind_of?(Array) ? backup_file.shift : backup_file
    end
  end
  

  #
  # doc tests
  #
  
  def test_documentation
    file_one = method_root.filepath(:output, "file.txt")
    file_two = method_root.filepath(:output, "path/to/file.txt")
    dir = method_root.filepath(:output, "some/dir")
    FileUtils.mkdir_p( method_root.filepath(:output) )
    
    File.open(file_one, "w") {|f| f << "original content"}
    t = Tap::FileTask.new do |task|
      task.mkdir(dir)                      
      task.prepare([file_one, file_two]) 
      
      File.open(file_one, "w") {|f| f << "new content"}
      FileUtils.touch(file_two)
  
      raise "error!"
    end
  
    begin
      assert !File.exists?(dir)        
      assert !File.exists?(file_two)        
      t.execute
      flunk "no error raised"
    rescue
      assert_equal "error!", $!.message
      assert !File.exists?(dir)        
      assert !File.exists?(file_two) 
      assert_equal "original content", File.read(file_one)  
    end
  end


  #
  # open tests
  #

  def test_open_doc
    FileUtils.mkdir_p(method_root.filepath(:output))
    one_filepath = method_root.filepath(:output, "one.txt")
    two_filepath = method_root.filepath(:output, "two.txt")

    t.open([one_filepath, two_filepath], "w") do |one, two|
      one << "one"
      two << "two"
    end

    assert_equal "one", File.read(one_filepath)
    assert_equal "two", File.read(two_filepath)

    #
    filepath = method_root.filepath(:output, "file.txt")
    t.open(filepath, "w") do |array|
      array.first << "content"
    end

    assert_equal "content", File.read(filepath) 
  end

  def test_open_opens_each_file
    FileUtils.mkdir_p(method_root.filepath(:output))

    list = [0, 1].collect do |n| 
      path = method_root.filepath(:output, "#{n}.txt")
      File.open(path, "w") {|f| f << n.to_s}
      path
    end

    t.open(list) do |files|
      files.each_with_index do |file, n|
        assert_equal File, file.class
        assert_equal n.to_s, file.read
      end
    end    
  end

  def test_open_opens_with_input_mode
    FileUtils.mkdir_p(method_root.filepath(:output))

    list = [0, 1].collect do |n| 
      path = method_root.filepath(:output, "#{n}.txt")
      path
    end

    t.open(list, "w") do |files|
      files.each_with_index do |file, n|
        assert_equal File, file.class
        file << n.to_s
      end
    end  

    list.each_with_index do |file, n|
      assert_equal n.to_s, File.read(file)
    end  
  end

  def test_open_returns_open_files_if_no_block_is_given
    FileUtils.mkdir_p(method_root.filepath(:output))

    list = [0, 1].collect do |n| 
      path = method_root.filepath(:output, "#{n}.txt")
      File.open(path, "w") {|f| f << n.to_s}
      path
    end

    t.open(list).each_with_index do |file, n|
      assert_equal File, file.class
      assert_equal n.to_s, file.read
      file.close
    end
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

  def uptodate_test_setup(output_str='')
    of1 = ctr.filepath(:root, 'old_file_one.txt')
    of2 = ctr.filepath(:root, 'old_file_two.txt')

    nf1 = method_tempfile('new_file_one.txt')
    File.open(nf1, "w") {|file| file << output_str}

    nf2 = method_tempfile('new_file_two.txt')
    File.open(nf2, "w") {|file| file << output_str}

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

    non = ctr.filepath(:output, "non_existant_file.txt")
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
  #   
  #   def test_uptodate_with_up_to_date_config_file
  #     t = Tap::FileTask.new "configured"
  #     
  #     of1, of2, nf1, nf2 = uptodate_test_setup
  #   
  #   non = ctr.filepath(:output, "non_existant_file.txt")
  #     assert !File.exists?(non)
  #     
  #     assert t.uptodate?(nf1)
  #   assert t.uptodate?(nf1, of1)
  #   assert t.uptodate?(nf1, [of1, of2])
  #   assert t.uptodate?(nf1, [of1, of2, non])
  #   assert t.uptodate?([nf1, nf2], of1)
  #     assert t.uptodate?([nf1, nf2], [of1, of2])
  #     
  #   assert !t.uptodate?(of1, nf1)
  #   assert !t.uptodate?(of1, [nf1, nf2])
  #   assert !t.uptodate?(non, nf1)
  #   assert !t.uptodate?(non, of1)
  #     assert !t.uptodate?([nf1, non], of1)
  #     assert !t.uptodate?([nf1, non], [of1, of2])
  #   end
  #   
  #   def test_uptodate_with_out_of_date_config_file
  #     filepath = ctr.filepath(:config, "configured-0.1.yml")
  #     assert !File.exists?(filepath)
  #     begin
  #       of1, of2, nf1, nf2 = uptodate_test_setup
  #       FileUtils.touch(filepath)
  #       t = Tap::FileTask.new "configured-0.1"
  # 
  #       assert !t.uptodate?(nf1)
  #       assert !t.uptodate?(nf1, of1)
  #       assert !t.uptodate?([nf1, nf2], [of1, of2])
  #     rescue
  #       raise $!
  #     ensure
  #       FileUtils.rm(filepath) if File.exists?(filepath)
  #     end
  #   end
  # 
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
    FileUtils.mkdir_p(method_root.filepath(:output))
    FileUtils.mkdir_p(method_root.filepath(:output))

    file = method_root.filepath(:output, "file.txt")
    File.open(file, "w") {|f| f << "file content"}

    t = Tap::FileTask.new
    t.app[:backup, true] = method_root.filepath(:backup)
    backed_up_file = t.backup(file).first   

    assert !File.exists?(file)                     
    assert File.exists?(backed_up_file)            
    assert_equal "file content", File.read(backed_up_file)         

    File.open(file, "w") {|f| f << "new content"}
    t.restore(file)

    assert File.exists?(file)                
    assert !File.exists?(backed_up_file)      
    assert_equal "file content", File.read(file)                 
  end

  def backup_test_setup
    existing_file = method_root.filepath(:output, "file.txt")
    backup_file = method_root.filepath(:output, "backup.txt")

    touch_file(existing_file, "existing content")
    t.extend BackupFile
    t.backup_file = backup_file
    
    [existing_file, backup_file]  
  end

  def test_backup_test_setup
    existing_file, backup_file = backup_test_setup

    assert File.exists?(existing_file)
    assert !File.exists?(backup_file)

    assert_equal "existing content", File.read(existing_file)
    assert_equal backup_file, t.backup_filepath(existing_file)
  end

  def test_backup_moves_filepath_to_backup_filepath
    existing_file, backup_file = backup_test_setup
  
    t.backup(existing_file)
  
    assert !File.exists?(existing_file)
    assert File.exists?(backup_file)
    assert_equal "existing content", File.read(backup_file)
  end
  
  def test_backup_copies_filepath_to_backup_filepath_if_backup_using_copy_is_true
    existing_file, backup_file = backup_test_setup
  
    t.backup(existing_file, true)
  
    assert File.exists?(existing_file)
    assert File.exists?(backup_file)
    assert FileUtils.compare_file(existing_file, backup_file)
  end
  
  def test_backup_registers_expanded_filepath_and_backup_filepath_in_backed_up_files
    existing_file, backup_file = backup_test_setup
  
    relative_filepath = Tap::Root.relative_filepath(Dir.pwd, existing_file)
    assert_not_equal existing_file, relative_filepath
  
    assert_equal existing_file, File.expand_path(existing_file)
    assert_equal existing_file, File.expand_path(relative_filepath)
    assert_equal backup_file, File.expand_path(backup_file)
  
    assert_equal({}, t.backed_up_files)
    t.backup(relative_filepath)
    assert_equal({existing_file => backup_file}, t.backed_up_files)
  end
  
  def test_backup_does_nothing_if_filepath_does_not_exist
    existing_file, backup_file = backup_test_setup
    FileUtils.rm(existing_file)
  
    assert !File.exists?(existing_file)
    assert !File.exists?(backup_file)
    assert_equal({}, t.backed_up_files)
  
    t.backup(existing_file)
  
    assert !File.exists?(existing_file)
    assert !File.exists?(backup_file)
    assert_equal({}, t.backed_up_files)  
  end
  
  def test_backup_raises_error_if_backup_for_file_already_exists
    existing_file, backup_file = backup_test_setup
    t.backup(existing_file, true)
  
    assert_raise(RuntimeError) { t.backup(existing_file) }
  end

  #
  # restore tests
  #
  
  def test_restore_restores_backed_up_file_to_original_location_as_listed_in_backed_up_files
    original_file = File.expand_path(method_root.filepath(:output, 'original/file.txt'))
    backup_file = File.expand_path(method_root.filepath(:output, 'backup/file.txt'))

    FileUtils.mkdir_p( File.dirname(original_file) )
    touch_file(backup_file)
    
    assert File.exists?(File.dirname(original_file))
    assert !File.exists?(original_file)
    assert File.exists?(backup_file)
    
    t.backed_up_files[original_file] = backup_file
    t.restore(original_file)
    
    assert File.exists?(original_file)
    assert !File.exists?(backup_file)
  end

  def test_restore_creates_dirs_as_needed_to_restore_file
    original_file = File.expand_path(method_root.filepath(:output, 'original/file.txt'))
    backup_file = File.expand_path(method_root.filepath(:output, 'backup/file.txt'))

    touch_file(backup_file)

    assert !File.exists?(File.dirname(original_file))
    assert !File.exists?(original_file)
    assert File.exists?(backup_file)

    t.backed_up_files[original_file] = backup_file
    t.restore(original_file)

    assert File.exists?(original_file)
    assert !File.exists?(backup_file)
  end

  def test_restore_does_nothing_if_the_input_file_is_not_backed_up
    assert !File.exists?("original_file")
    assert t.backed_up_files.empty?
    assert_equal [], t.restore("original_file")
    assert !File.exists?("original_file")
  end

  def test_restore_removes_backup_dir_using_rmdir
    original_file = File.expand_path(method_root.filepath(:output, 'original/file.txt'))
    backup_file = File.expand_path(method_root.filepath(:output, 'backup/file.txt'))
    backup_dir = File.dirname(backup_file)

    t.mkdir(backup_file)
    assert File.exists?(backup_dir)

    touch_file(backup_file)

    t.backed_up_files[original_file] = backup_file
    t.restore(original_file)

    assert !File.exists?(backup_dir)
  end

  def test_restore_acts_on_list_and_returns_restored_files
    existing_file0 = File.expand_path(method_root.filepath(:output, "file0.txt"))
    existing_file1 = File.expand_path(method_root.filepath(:output, "file1.txt"))
    backup_file0 = File.expand_path(method_root.filepath(:output, "backup0.txt"))
    backup_file1 = File.expand_path(method_root.filepath(:output, "backup1.txt"))

    touch_file(backup_file0)
    touch_file(backup_file1)

    t.backed_up_files[existing_file0] = backup_file0
    t.backed_up_files[existing_file1] = backup_file1

    assert !File.exists?(existing_file0)
    assert !File.exists?(existing_file1)

    assert_equal [existing_file0, existing_file1], t.restore([existing_file0, existing_file1])

    assert File.exists?(existing_file0)
    assert File.exists?(existing_file1)
  end

  #
  # mkdir tests
  #

  def test_mkdir_documentation
    dir_one = method_root.filepath(:output, "path/to/dir")
    dir_two = method_root.filepath(:output, "path/to/another")

    t = Tap::FileTask.new do |task, inputs|
      assert !File.exists?(method_root.filepath(:output, "path"))  

      task.mkdir(dir_one)             
      assert File.exists?(dir_one)           

      FileUtils.mkdir(dir_two)   
      assert File.exists?(dir_two)    

      raise "error!"
    end

    begin
      t.execute(nil)
      flunk "no error raised"
    rescue
      assert_equal "error!", $!.message     
      assert !File.exists?(dir_one)  
      assert File.exists?(dir_two)    
    end
  end

  def test_mkdir_creates_dir_if_it_does_not_exist
    dir = method_root.filepath(:output, 'path/to/non_existant_folder')
    FileUtils.mkdir_p(File.dirname(dir))
    assert !File.exists?(dir)

    t.mkdir(dir)
    assert File.exists?(dir)
  end

  def test_mkdir_creates_parent_dirs_if_they_do_not_exist
    dir = method_root.filepath(:output, 'path/to/non_existant_folder')
    assert !File.exists?(method_root.filepath(:output))

    t.mkdir(dir)
    assert File.exists?(dir)
  end

  def test_mkdir_registers_expanded_dir_and_all_non_existing_parent_dirs_in_added_files
    dir = method_root.filepath(:output, 'path/to/non_existant_folder')
    assert_equal [], t.added_files

    relative_dir = Tap::Root.relative_filepath(Dir.pwd, dir)
    assert_not_equal dir, relative_dir
    assert_equal dir, File.expand_path(relative_dir)

    t.mkdir(relative_dir)

    expected = [
      method_root,
      method_root.filepath(:output),
      method_root.filepath(:output, 'path'),
      method_root.filepath(:output, 'path/to'),
      method_root.filepath(:output, 'path/to/non_existant_folder')
    ]

    assert_equal expected, t.added_files
  end

  def test_mkdir_acts_on_and_returns_list
    dir = method_root.filepath(:output, 'path')
    another = method_root.filepath(:output, 'another')

    assert !File.exists?(dir)
    assert !File.exists?(another)

    assert_equal [dir, another], t.mkdir([dir, another])

    assert File.exists?(dir)
    assert File.exists?(another)
  end

  #
  # rmdir tests
  #

  def test_rmdir_documentation
    dir_one = method_root.filepath(:output, 'path')
    dir_two = method_root.filepath(:output, 'path/to/dir')
    FileUtils.mkdir_p( method_root.filepath(:output) )

    t = Tap::FileTask.new
    assert !File.exists?(dir_one)            
    FileUtils.mkdir(dir_one)         

    t.mkdir(dir_two)           
    assert File.exists?(dir_two)     

    t.rmdir(dir_two)                
    assert File.exists?(dir_one)           
    assert !File.exists?(method_root.filepath(:output, 'path/to'))    
  end

  def test_rmdir_removes_dir_if_made_by_the_task
    dir = method_root.filepath(:output, 'path/to/non_existant_folder')
    existing_dir = method_root.filepath(:output, 'path/to')

    FileUtils.mkdir_p(existing_dir)
    assert File.exists?(existing_dir)
    assert !File.exists?(dir)

    t.mkdir(dir)
    assert File.exists?(dir)

    t.rmdir(dir)
    assert File.exists?(existing_dir)
    assert !File.exists?(dir)
  end

  def test_rmdir_removes_parent_dirs_if_made_by_the_task
    dir = method_root.filepath(:output, 'path/to/non/existant/folder')
    root_parent_dir = method_root.filepath(:output, 'path/to')
    existing_dir = method_root.filepath(:output, 'path')

    FileUtils.mkdir_p(existing_dir)
    assert File.exists?(existing_dir)
    assert !File.exists?(root_parent_dir)

    t.mkdir(dir)
    assert File.exists?(dir)

    t.rmdir(dir)
    assert File.exists?(existing_dir)
    assert !File.exists?(root_parent_dir)
  end

  def test_rmdir_does_not_remove_if_dir_was_not_made_by_task
    dir = method_root.filepath(:output, 'path/to/non_existant_folder')

    FileUtils.mkdir_p(dir)
    assert File.exists?(dir)

    t.rmdir(dir)
    assert File.exists?(dir)
  end

  def test_rmdir_does_not_remove_if_folder_is_not_empty
    dir = method_root.filepath(:output, 'path/to/folder')
    not_empty_dir = method_root.filepath(:output, 'path/to')

    t.mkdir(dir)
    assert File.exists?(dir)

    touch_file File.join(not_empty_dir, "file.txt")

    t.rmdir(dir)
    assert File.exists?(not_empty_dir)
    assert !File.exists?(dir)
  end

  def test_rmdir_checks_for_hidden_files_as_well_as_regular_files
    dir = method_root.filepath(:output, 'path/to/folder')
    not_empty_dir = method_root.filepath(:output, 'path/to')

    t.mkdir(dir)
    assert File.exists?(dir)

    touch_file File.join(not_empty_dir, ".hidden_file")

    t.rmdir(dir)
    assert File.exists?(not_empty_dir)
    assert !File.exists?(dir)
  end

  def test_rmdir_clears_added_files_of_removed_dirs
    dir = method_root.filepath(:output, 'path/to/folder')

    FileUtils.mkdir_p(method_root.filepath(:output))
    assert_equal [], t.added_files

    t.mkdir(dir)
    assert_equal [
      File.expand_path(method_root.filepath(:output, 'path')),
      File.expand_path(method_root.filepath(:output, 'path/to')),
      File.expand_path(method_root.filepath(:output, 'path/to/folder'))
    ], t.added_files

    # touch a file so the 'path' folder isn't removed
    touch_file method_root.filepath(:output, 'path/file.txt')

    t.rmdir(dir)
    assert_equal [File.expand_path(method_root.filepath(:output, 'path'))], t.added_files
  end

  def test_rmdir_acts_on_and_returns_expanded_list_of_removed_dirs
    dir = method_root.filepath(:output, 'path')
    another = method_root.filepath(:output, 'another')
    not_removed = method_root.filepath(:output, 'not')
    removed = method_root.filepath(:output, 'not/removed')

    t.mkdir([dir, another, not_removed, removed])
    # touch a file so the not_removed folder isn't removed
    touch_file method_root.filepath(:output, 'not/file.txt')

    expected = [dir, another, removed].collect {|d| File.expand_path(d)}
    assert_equal expected, t.rmdir([dir, another, not_removed, removed])
  end

  #
  # prepare tests
  #

  def test_prepare_documentation
    file_one = method_root.filepath(:output, "file.txt")
    file_two = method_root.filepath(:output, "path/to/file.txt")
    FileUtils.mkdir_p( method_root.filepath(:output) )

    File.open(file_one, "w") {|f| f << "original content"}
    t = Tap::FileTask.new do |task, inputs|
      assert !File.exists?(method_root.filepath(:output, "path"))

      # backup... prepare parent dirs... prepare for restore     
      task.prepare([file_one, file_two]) 

      File.open(file_one, "w") {|f| f << "new content"}
      FileUtils.touch(file_two)

      raise "error!"
    end

    begin
      t.execute(nil)
      flunk "no error raised"
    rescue
      assert_equal "error!", $!.message
      assert File.exists?(file_one)           
      assert_equal "original content", File.read(file_one) 
      assert !File.exists?(method_root.filepath(:output, "path"))   
    end
  end

  def test_prepare_acts_on_and_returns_list
    filepath = "file.txt"
    another = "another.txt"
    assert_equal [filepath, another], t.prepare([filepath, another])
  end

  def test_prepare_backs_up_existing_files_and_creates_non_existant_dirs
    existing_file = method_root.filepath(:output, "path/to/existing/file.txt")
    backup_file = method_root.filepath(:output, "path/to/existing/file_backup.txt")
    non_existant_file = method_root.filepath(:output, "path/to/non/existant/file.txt")
    touch_file(existing_file, "existing content")

    # be sure backup_filepath_leads to output_file for easy cleanup
    t.extend BackupFile
    t.backup_file = backup_file
    
    assert File.exists?(existing_file)
    assert !File.exists?(non_existant_file)

    files = [existing_file, non_existant_file]
    t.prepare(files) 

    # check neither of the files exist at this point
    # and the parent dirs all exist
    files.each do |file|
      assert !File.exists?(file)
      assert File.exists?(File.dirname(file))
    end

    # check the existing file was backed up
    assert_equal({File.expand_path(existing_file) => backup_file}, t.backed_up_files)
    assert_equal "existing content", File.read(backup_file)
  end

  def test_prepare_adds_list_to_added_files
    existing_file = method_root.filepath(:output, "path/to/existing/file.txt")
    backup_file = method_root.filepath(:output, "path/to/existing/file_backup.txt")
    non_existant_file = method_root.filepath(:output, "path/to/non/existant/file.txt")
    touch_file(existing_file)

    # be sure backup_filepath_leads to output_file for easy cleanup
    t.extend BackupFile
    t.backup_file = backup_file

    assert_equal([], t.added_files)
    assert File.exists?(existing_file)
    assert !File.exists?(non_existant_file)
    assert !File.exists?(backup_file)

    files = [existing_file, non_existant_file]
    t.prepare(files)

    expected = [
      method_root.filepath(:output, 'path/to/non'),          # added by mkdir
      method_root.filepath(:output, 'path/to/non/existant'), # added by mkdir
      existing_file,                                    # added by prepare
      non_existant_file                                 # added by prepare
    ].collect do |dir|
      File.expand_path(dir)
    end

    assert_equal expected, t.added_files
  end

  #
  # rm tests
  #

  def test_rm_documentation
    dir = method_root.filepath(:output, 'path')
    file = method_root.filepath(:output, 'path/to/file.txt')
    FileUtils.mkdir_p( method_root.filepath(:output) )

    t = Tap::FileTask.new
    assert !File.exists?(dir)            
    FileUtils.mkdir(dir)         

    t.prepare(file)        
    FileUtils.touch(file)   
    assert File.exists?(file)     

    t.rm(file)                
    assert File.exists?(dir)           
    assert !File.exists?(method_root.filepath(:output, 'path/to'))    
  end

  def test_rm_removes_file_and_parent_dirs_if_made_by_the_task
    file = method_root.filepath(:output, 'path/to/file.txt')
    parent_dir = method_root.filepath(:output, 'path/to')
    existing_dir = method_root.filepath(:output, 'path')
    FileUtils.mkdir_p existing_dir

    assert File.exists?(existing_dir)
    assert !File.exists?(file)

    t.prepare file
    touch_file(file)
    assert File.exists?(file)

    t.rm(file)
    assert File.exists?(existing_dir)
    assert !File.exists?(parent_dir)
    assert !File.exists?(file)
  end

  def test_rm_removes_parent_dirs_even_if_file_does_not_exist
    file = method_root.filepath(:output, 'path/to/file.txt')
    parent_dir = method_root.filepath(:output, 'path/to')
    existing_dir = method_root.filepath(:output, 'path')
    FileUtils.mkdir_p existing_dir

    assert File.exists?(existing_dir)
    assert !File.exists?(file)

    t.prepare file
    assert !File.exists?(file)

    t.rm(file)
    assert File.exists?(existing_dir)
    assert !File.exists?(parent_dir)
  end

  def test_rm_does_not_remove_file_if_not_made_by_the_task
    file = method_root.filepath(:output, 'path/to/file.txt')

    touch_file(file)
    assert File.exists?(file)

    t.rm(file)
    assert File.exists?(file)
  end

  def test_rm_clears_added_files_of_removed_files
    file0 = method_root.filepath(:output, 'file0.txt')
    file1 = method_root.filepath(:output, 'file1.txt')

    FileUtils.mkdir_p(method_root.filepath(:output))
    assert_equal [], t.added_files

    t.prepare([file0,file1])
    assert_equal [
      File.expand_path(method_root.filepath(:output, 'file0.txt')),
      File.expand_path(method_root.filepath(:output, 'file1.txt'))
    ], t.added_files

    t.rm(file0)
    assert_equal [File.expand_path(method_root.filepath(:output, 'file1.txt'))], t.added_files
  end

  def test_rm_acts_on_and_returns_expanded_list_of_removed_files_and_dirs
    file = method_root.filepath(:output, 'file.txt')
    another = method_root.filepath(:output, 'another.txt')
    not_removed = method_root.filepath(:output, 'not')
    removed = method_root.filepath(:output, 'not/removed.txt')

    t.prepare([file, another, removed])
    # touch a file so the not_removed folder isn't removed
    touch_file method_root.filepath(:output, 'not/file.txt')

    expected = [file, another, removed].collect {|f| File.expand_path(f)}
    assert_equal expected, t.rm([file, another, removed])
  end

  #
  # execute tests
  #

  def setup_execute_test(&block)
    existing_file = method_root.filepath(:output, "path/to/existing/file.txt")
    non_existant_dir = method_root.filepath(:output, "path/to/non/existing")
    non_existant_file = File.join(non_existant_dir, "file.txt")
    backup_file = method_root.filepath(:output, "backup/file.txt")

    touch_file(existing_file, "original content")
    @t = Tap::FileTask.new do |task, input|
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
    t.execute(nil)
  end

  def test_execute_restores_backups_and_removes_added_files_on_error
    was_in_execute = false
    existing_file, backup_file, non_existant_dir, non_existant_file = setup_execute_test do 
      was_in_execute = true
      raise "error"
    end

    assert_raise(RuntimeError) { t.execute(nil)  }

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
    assert_raise(RuntimeError) { t.execute(nil)  }

    # check the existing file was NOT restored
    assert was_in_execute
    assert !File.exists?(existing_file)
    assert File.exists?(non_existant_dir)
    assert File.exists?(backup_file)
    assert_equal "original content", File.read(backup_file)
    assert !t.added_files.empty?
    assert !t.backed_up_files.empty?
  end

  def test_execute_does_not_rollback_results_from_prior_successful_executions
    existing_file = method_root.filepath(:output, "path/to/existing/file.txt")
    non_existant_dir = method_root.filepath(:output, "path/to/non/existing")
    non_existant_file = File.join(non_existant_dir, "file.txt")
    backup_file = method_root.filepath(:output, "backup/file.txt")

    touch_file(existing_file, "original content")
    count = 0
    @t = Tap::FileTask.new do |task, input|
      if count > 0
        count = 2
        raise "error" 
      else
        count = 1
        task.prepare([existing_file, non_existant_file]) 
        touch_file(existing_file, "new content")
      end
    end

    # assure the backup goes where expected
    t.extend BackupFile
    t.backup_file = backup_file

    # assert !t.cleanup_after_execute

    assert_nothing_raised { t.execute(nil)  }
    assert_equal 1, count
    assert File.exists?(existing_file)
    assert_equal "new content", File.read(existing_file)   
    assert File.exists?(non_existant_dir)
    assert File.exists?(backup_file)
    assert_equal "original content", File.read(backup_file)   

    assert_raise(RuntimeError) { t.execute(nil)  }

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
      path = method_root.filepath(:output, "path/to/existing/file#{n}.txt")
      touch_file path, n.to_s
      path
    end
    
    backup_files = existing_files.collect do |file|
      method_root.filepath(:output, File.basename(file) + "_backup")
    end

    non_existant_files =  [0,1].collect do |n|
      method_root.filepath(:output, "path/to/non/existing/file#{n}.txt")
    end

    @t = Tap::FileTask.new do |task, input|
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
    t.execute(nil)
  end

  def test_execute_restore_and_removal_with_multiple_files
    was_in_execute = false
    existing_files, non_existant_files = setup_multiple_file_execute_test do
      was_in_execute = true
      (existing_files + non_existant_files) .each do |file|
        touch_file file, "new content"
      end
      raise "error"
    end

    assert !File.exists?(method_root.filepath(:output, 'backup'))
    assert_raise(RuntimeError) { t.execute(nil) }

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
