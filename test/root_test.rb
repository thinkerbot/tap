require File.join(File.dirname(__FILE__), 'tap_test_helper.rb') 
require 'tap/root'

class RootTest < Test::Unit::TestCase
  include Tap::Test::SubsetMethods
  
  attr_reader :r, :tr
  
  def setup
    # root
    @r = Tap::Root.new "./root", {:dir => "dir"}, {:abs => '/abs/path'}
    
    # test root
    @tr = Tap::Root.new root_dir, {:lib => "lib"}
  end
  
  def root_dir 
    File.expand_path(File.join(File.dirname(__FILE__), 'root'))
  end
  
  def path_root
    path_root = File.expand_path(".")
    while (parent_dir = File.dirname(path_root)) != path_root
      path_root = parent_dir
    end
    
    path_root
  end
  
  def test_documentation
    r = Tap::Root.new root_dir, :input => 'in', :output => 'out'
    
    # work with directories
    assert_equal root_dir + '/in', r[:input]         
    assert_equal root_dir + '/out', r[:output]        
    assert_equal root_dir + '/implicit', r['implicit']   
    
    # expanded paths are returned unchanged
    assert_equal File.expand_path('expanded'), r[File.expand_path('expanded')]
  
    # work with filepaths
    assert_equal root_dir + '/in/path/to/file.txt', fp = r.filepath(:input, 'path/to/file.txt')   
    assert_equal 'path/to/file.txt', r.relative_filepath(:input, fp)               
    assert_equal root_dir + '/out/path/to/file.txt', r.translate(fp, :input, :output)                 
     
    # version filepaths
    assert_equal 'path/to/config-1.0.yml', r.version('path/to/config.yml', 1.0)           
    assert_equal 'path/to/config-1.1.yml', r.increment('path/to/config-1.0.yml', 0.1)     
    assert_equal ['path/to/config.yml', "1.1"], r.deversion('path/to/config-1.1.yml')          
    
    # absolute paths can also be aliased. 
    r[:abs, true] = "/absolute/path"      
    assert_equal File.expand_path('/absolute/path/to/file.txt'), r.filepath(:abs, "to", "file.txt")
  end
  
  #
  # Tap::Root relative filepath test
  #
  
  def test_relative_filepath_documentation
    assert_equal "path/to/file.txt", Tap::Root.relative_filepath('dir', "dir/path/to/file.txt")  
  end
  
  def test_class_relative_filepath 
    assert_equal "file.txt", Tap::Root.relative_filepath('./root/dir', "./root/dir/file.txt")
    assert_equal "nested/file.txt", Tap::Root.relative_filepath('./root/dir', "./root/dir/nested/file.txt")
  end

  def test_class_relative_filepath_expands_paths
    assert_equal "file.txt", Tap::Root.relative_filepath('./root/dir', "./root/folder/.././dir/file.txt")
    assert_equal "file.txt", Tap::Root.relative_filepath('./root/dir', "root/dir/file.txt")
    assert_equal "file.txt", Tap::Root.relative_filepath('root/dir', "./root/dir/file.txt")
    assert_equal "file.txt", Tap::Root.relative_filepath('root/dir', "root/dir/file.txt")
  end
    
  def test_class_relative_filepath_raises_error_if_path_is_not_relative_to_dir
    assert_raise(RuntimeError) { Tap::Root.relative_filepath('dir', "./root/file.txt") }
  end
  
  def test_class_relative_filepath_path_root
    if self.class.match_platform?("mswin")
      assert path_root =~ /^[A-z]:\/$/
      assert_equal "path/to/file.txt", Tap::Root.relative_filepath(path_root, path_root + "path/to/file.txt")
    else
      assert_equal "path/to/file.txt", Tap::Root.relative_filepath(path_root, path_root + "path/to/file.txt")
    end
  end
  
  #
  # Tap::Root glob test
  #
  
  def test_class_glob_returns_all_unique_files_matching_input_patterns
    files = [root_dir + "/glob/one.txt", root_dir + "/glob/two.txt"]
    
    assert_equal files, Tap::Root.glob(root_dir + "/glob/**/*").sort
    assert_equal files, Tap::Root.glob(root_dir + "/glob/one.txt", root_dir + "/glob/two.txt").sort
    assert_equal files, Tap::Root.glob(root_dir + "/glob/**/*", root_dir + "/glob/one.txt", root_dir + "/glob/two.txt").sort
    assert_equal [], Tap::Root.glob(root_dir + "/glob/three.txt")
    assert_equal [], Tap::Root.glob()
  end

  #
  # Tap::Root vglob test
  #
  
  def test_class_vglob_returns_all_versions_matching_file_and_version_pattern
    assert_equal 4, Dir.glob(File.join(root_dir, 'versions/*')).length

    assert_equal 3, Dir.glob(File.join(root_dir, 'versions/file*.yml')).length
    assert_equal Dir.glob(root_dir + '/versions/file*.yml').sort, Tap::Root.vglob(root_dir + '/versions/file.yml', '*').sort
    
    assert_equal 2, Dir.glob(File.join(root_dir, 'versions/file-0.1*.yml')).length
    assert_equal Dir.glob(root_dir + '/versions/file-0.1*.yml').sort, Tap::Root.vglob(root_dir + '/versions/file.yml', '0.1*').sort
   
    assert_equal 1, Dir.glob(File.join(root_dir, 'versions/file-0.1.yml')).length
    assert_equal Dir.glob(root_dir + '/versions/file-0.1.yml').sort, Tap::Root.vglob(root_dir + '/versions/file.yml', '0.1').sort
    
    assert_equal 0, Dir.glob(File.join(root_dir, 'versions/file-2.yml')).length
    assert_equal [], Tap::Root.vglob(root_dir + '/versions/file.yml', '2')
  end
  
  def test_class_default_vglob_pattern_is_all_versions
    expected = Dir.glob(File.join(root_dir + '/versions/file*.yml'))
    assert_equal expected.sort, Tap::Root.vglob(root_dir + '/versions/file.yml').sort
  end
  
  #
  # Tap::Root indir test
  #
  
  def test_indir_executes_block_in_the_specified_directory
    test_dir = root_dir
    pwd = File.expand_path(Dir.pwd)
    
    assert_not_equal pwd, test_dir
    assert File.directory?(test_dir)
    
    was_in_block = false
    begin
      res = Tap::Root.indir(test_dir) do 
        was_in_block = true
        assert_equal test_dir, File.expand_path(Dir.pwd)
        "result"
      end
      assert_equal "result", res
    ensure
      Dir.chdir(pwd)
    end
    
    assert_equal pwd, File.expand_path(Dir.pwd)
    assert was_in_block
  end
  
  def test_indir_raises_error_for_non_dir_inputs
    test_dir = root_dir + '/non/existant/dir'
    filepath = root_dir + '/file.txt'
    pwd = File.expand_path(Dir.pwd)

    assert !File.exists?(root_dir + '/non')
    assert File.exists?(filepath) 
    assert File.file?(filepath)
    begin
      assert_raise(RuntimeError) { Tap::Root.indir(filepath) {} }
      assert_raise(RuntimeError) { Tap::Root.indir(filepath) {} }
    ensure
      Dir.chdir(pwd)
    end
    
    assert_equal pwd, File.expand_path(Dir.pwd)
  end
  
  def test_indir_creates_directory_if_specified
    test_dir = root_dir + '/non/existant/dir'
    pwd = File.expand_path(Dir.pwd)
    
    assert_not_equal pwd, test_dir
    assert !File.exists?(root_dir + '/non')

    was_in_block = false
    begin
      Tap::Root.indir(test_dir, true) do 
        was_in_block = true
        assert_equal test_dir, File.expand_path(Dir.pwd)
        assert File.exists?(test_dir)
      end
    ensure
      Dir.chdir(pwd)
      FileUtils.rm_r(root_dir + '/non') if File.exists?(root_dir + '/non')
    end
    
    assert_equal pwd, File.expand_path(Dir.pwd)
    assert was_in_block
  end
  
  #
  # Tap::Root path_root_type test
  #
  
  def test_path_root_type
    case
    when self.class.match_platform?("mswin")
      assert_equal :win, Tap::Root.path_root_type
    when File.expand_path(".")[0] == ?/
      assert_equal :nix, Tap::Root.path_root_type
    else
      assert_equal :unknown, Tap::Root.path_root_type
    end
  end
  
  #
  # Tap::Root.expaned_path? test
  #

  def test_expanded_path_documentation
    assert Tap::Root.expanded_path?("C:/path", :win)
    assert Tap::Root.expanded_path?("c:/path", :win)
    assert Tap::Root.expanded_path?("D:/path", :win)
    assert !Tap::Root.expanded_path?("path", :win)

    assert Tap::Root.expanded_path?('/path', :nix)
    assert !Tap::Root.expanded_path?('path', :nix)
  end
  
  def test_expanded_path
    assert Tap::Root.expanded_path?("C:/path", :win)
    assert Tap::Root.expanded_path?("c:/path", :win)
    assert Tap::Root.expanded_path?("D:/path", :win)
    assert !Tap::Root.expanded_path?("/path", :win)
    assert !Tap::Root.expanded_path?("path", :win)

    assert Tap::Root.expanded_path?("/path", :nix)
    assert !Tap::Root.expanded_path?("C:/path", :nix)
    assert !Tap::Root.expanded_path?("path", :nix)
    
    assert_nil Tap::Root.expanded_path?("C:/path", :other)
    assert_nil Tap::Root.expanded_path?("/path", :other)
    assert_nil Tap::Root.expanded_path?("path", :other)
  end
  
  #
  # initialize tests
  #
  
  def test_default_root_is_expanded_dir_pwd
    r = Tap::Root.new
    
    assert_equal File.expand_path(Dir.pwd), r.root
    assert_equal({}, r.directories)
  end
  
  def test_initialize_root
    r = Tap::Root.new "./root", {:dir => "dir", :temp => "tmp"}, {:abs => "/abs/path"}
    
    assert_equal File.expand_path("./root"), r.root
    assert_equal({:dir => "dir", :temp => "tmp"}, r.directories)
    assert_equal({:abs => File.expand_path("/abs/path")}, r.absolute_paths)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"), 
      :temp =>  File.expand_path( "./root/tmp"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def test_any_object_can_be_used_as_a_directory_alias
    r = Tap::Root.new("./root", 'dir' => "str_da",  :dir => 'sym_da', 1 => 'n_da')
    
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      'dir' =>  File.expand_path("./root/str_da"), 
      :dir =>   File.expand_path("./root/sym_da"), 
      1 =>      File.expand_path("./root/n_da")}, 
    r.paths)
  end
  
  def test_path_root
    case
    when self.class.match_platform?("mswin")
      assert r.path_root =~ /^[A-z]:\/$/i
    when self.class.match_platform?("darwin")
      assert r.path_root == '/'
    else
      expected_path_root = File.expand_path(".")
      while (parent_dir = File.dirname(expected_path_root)) != expected_path_root
        expected_path_root = parent_dir
      end
      assert_equal expected_path_root, r.path_root
    end
  end

  #
  # set root tests
  #
  
  def test_set_root_resets_paths
    r.root = './another'
    
    assert_equal File.expand_path("./another"), r.root
    assert_equal({:dir => "dir"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./another"), 
      :root =>  File.expand_path("./another"), 
      :dir =>   File.expand_path("./another/dir"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def root_dir_cannot_be_set_through_index
    assert_raise(ArgumentError) { r['root'] = './another' }
  end
  
  #
  # set directories tests
  #
  
  def test_directories_documentation
    assert_equal File.join(r.root, 'alt'), r['alt']
    r.directories = {'alt' => "dir"}
    assert_equal File.join(r.root, 'dir'), r['alt']
  end
  
  def test_set_directories
    r.directories = {:alt => "dir"}

    assert_equal({:alt => "dir"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :alt =>   File.expand_path("./root/dir"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def test_raise_error_when_trying_to_set_root_through_directories
    assert_raise(ArgumentError) { r.directories = {'root' => "another"} }
  end
  
  #
  # set absolute paths test
  #
  
  def test_absolute_paths_documentation
    assert_equal File.join(r.root, 'abs'), r['abs']
    r.absolute_paths = {'abs' => File.expand_path("/path/to/dir")}
    assert_equal File.expand_path("/path/to/dir"), r['abs']
  end

  def test_set_absolute_paths
    r.absolute_paths = {:absolute => "/absolute/path"}

    assert_equal({:dir => "dir"}, r.directories)
    assert_equal({
      'root' =>    File.expand_path("./root"), 
      :root =>     File.expand_path("./root"), 
      :dir =>      File.expand_path("./root/dir"), 
      :absolute => File.expand_path("/absolute/path")}, 
    r.paths)
  end
  
  def test_raise_error_when_trying_to_set_root_through_absolute_paths
    assert_raise(ArgumentError) { r.absolute_paths = {'root' => "another"} }
  end
  
  #
  # get absolute paths test
  #
  
  def test_absolute_paths_returns_all_non_root_paths_with_no_directory
    assert_equal({:abs => File.expand_path("/abs/path")}, r.absolute_paths)
    
    r.paths[:another] = File.expand_path("/another/path")
    assert_equal({
      :abs =>     File.expand_path("/abs/path"), 
      :another => File.expand_path("/another/path")}, 
    r.absolute_paths)
  end
  
  #
  # assignment tests
  #
  
  def test_assignment_documentation
    r = Tap::Root.new root_dir
    r[:dir] = 'path/to/dir'
    assert_equal root_dir + '/path/to/dir', r[:dir]

    r[:abs, true] = '/abs/path/to/dir'  
    assert_equal File.expand_path('/abs/path/to/dir'), r[:abs]
  end
  
  def test_set_existing_directory_using_assignment
    r[:dir] = 'another'
    
    assert_equal({:dir => "another"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/another"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
  end
  
  def test_set_new_directory_using_assignment
    r[:new] = 'new'

    assert_equal({:dir => "dir", :new => "new"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"),
      :abs =>   File.expand_path("/abs/path"), 
      :new =>   File.expand_path("./root/new")}, 
    r.paths)
  end

  def test_absolute_paths_can_be_set_by_specifiying_absolute_true
    r[:absolute, true] = '/some/absolute/path'
    
    assert_equal({:dir => "dir"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"),
      :abs =>   File.expand_path("/abs/path"), 
      :absolute => File.expand_path('/some/absolute/path')},
    r.paths)
  end
  
  def test_an_absolute_path_is_not_set_if_absolute_false
    r[:not_absolute, false] = 'not/an/absolute/path'
    
    assert_equal({:dir => "dir", :not_absolute => "not/an/absolute/path"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"), 
      :abs =>   File.expand_path("/abs/path"), 
      :not_absolute => File.expand_path("./root/not/an/absolute/path")}, 
    r.paths)
  end
  
  def test_paths_can_be_unset_with_nil
    # Non-absolute path
    r[:dir] = '/some/path'
    assert_equal({:dir => "/some/path"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/some/path"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
    
    r[:dir] = nil
    assert_equal({}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)

    # the same with absolute specified
    r[:dir] = '/some/path'
    assert_equal({:dir => "/some/path"}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/some/path"), 
      :abs =>   File.expand_path("/abs/path")}, 
    r.paths)
    
    r[:dir, false] = nil
    assert_equal({}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs => File.expand_path("/abs/path")}, 
    r.paths)

    # Absolute path
    r[:abs, true] = '/some/absolute/path'
    assert_equal({}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs =>   File.expand_path('/some/absolute/path')}, 
    r.paths)
    
    r[:abs, true] = nil
    assert_equal({}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root")}, 
    r.paths)
    
    # the same with absolute unspecfied
    r[:abs, true] = '/some/absolute/path'
    assert_equal({}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :abs =>   File.expand_path('/some/absolute/path')}, 
    r.paths)
    
    r[:abs] = nil
    assert_equal({}, r.directories)
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root")}, 
    r.paths)
  end
  
  def test_set_path_expands_filepaths
    r[:dir] = "./sub/../dir"
    assert_equal File.expand_path("./root/dir"), r.paths[:dir]
    
    r[:abs, true] = "/./sub/../dir"
    assert_equal File.expand_path("/dir"), r.paths[:abs]
  end
  
  #
  # retrieve path tests
  #
  
  def test_retrieve_documentation
    r = Tap::Root.new root_dir, :dir => 'path/to/dir'
    assert_equal root_dir + '/path/to/dir', r[:dir]

    assert_equal root_dir + '/relative/path', r['relative/path']
    
    expanded_path = File.expand_path('/expanded/path')
    assert_equal expanded_path, r[expanded_path]
  end
  
  def test_retrieve_paths
    {
      :dir =>   File.expand_path("./root/dir"),
      :root =>  File.expand_path("./root"),
      'root' => File.expand_path("./root"),
      :abs => File.expand_path("/abs/path")
    }.each_pair do |dir, expected|
      assert_equal expected, r[dir]
    end
  end
  
  def test_retrieve_path_infers_path_if_path_is_not_set
    assert_equal({
      'root' => File.expand_path("./root"), 
      :root =>  File.expand_path("./root"), 
      :dir =>   File.expand_path("./root/dir"), 
      :abs => File.expand_path("/abs/path")}, 
    r.paths)
    assert_equal File.expand_path("./root/not_set"), r[:not_set]
    assert_equal File.expand_path("./root/nested/dir"), r['nested/dir']
  end
  
  def test_retrieve_path_expands_inferred_filepaths
    assert_equal File.expand_path("./root/nested/dir"), r['./sub/../nested/dir']
  end

  #
  # filepath tests
  #
  
  def test_filepath
    assert_equal File.expand_path("./root/dir"), r[:dir]
    assert_equal File.expand_path("./root/dir/file.txt"), r.filepath(:dir, "file.txt")
    assert_equal File.expand_path("./root/dir/nested/file.txt"), r.filepath(:dir, "nested/file.txt")
  end
  
  def test_filepath_when_path_is_not_set
    assert_equal File.expand_path("./root/not_set/file.txt"), r.filepath(:not_set, "file.txt")
    assert_equal File.expand_path("./root/folder/subfolder/file.txt"), r.filepath('folder/subfolder', "file.txt")
    assert_equal File.expand_path("./root/folder/subfolder/file.txt"), r.filepath('folder/subfolder/', "file.txt")
    assert_equal File.expand_path(path_root + "folder/subfolder/file.txt"), r.filepath(path_root + 'folder/subfolder', "file.txt")
  end
  
  def test_filepath_expands_paths
    assert_equal File.expand_path("./root/dir"), r[:dir]
    assert_equal File.expand_path("./root/dir/file.txt"), r.filepath(:dir, "./sub/../file.txt")
    assert_equal File.expand_path("./root/dir/nested/file.txt"), r.filepath(:dir, "nested/./sub/../file.txt")
  end
  
  #
  # relative filepath tests
  #
  
  def test_relative_filepath
    assert_equal "file.txt", r.relative_filepath(:dir, "./root/dir/file.txt")
    assert_equal "nested/file.txt", r.relative_filepath(:dir, "./root/dir/nested/file.txt")
    assert_equal "file.txt", r.relative_filepath('dir/nested', "./root/dir/nested/file.txt")
    assert_equal "file.txt", r.relative_filepath('dir/nested/', "./root/dir/nested/file.txt")
    assert_equal "file.txt", r.relative_filepath(path_root + 'dir/nested', path_root + "dir/nested/file.txt")
  end

  def test_relative_filepath_when_path_equals_input
    assert_equal "", r.relative_filepath(:dir, "./root/dir")
    assert_equal "", r.relative_filepath(:dir, "./root/dir/")
  end
  
  def test_relative_filepath_expands_paths
    assert_equal "file.txt", r.relative_filepath(:dir, "./root/folder/.././dir/file.txt")
    assert_equal "file.txt", r.relative_filepath(:dir, "root/dir/file.txt")
  end
    
  def test_relative_filepath_when_path_is_not_set
    assert_equal "file.txt", r.relative_filepath(:not_set, "./root/not_set/file.txt")
    assert_equal "file.txt", r.relative_filepath('folder/subfolder', "./root/folder/subfolder/file.txt")
    assert_equal "file.txt", r.relative_filepath('folder/subfolder/', "./root/folder/subfolder/file.txt")
    assert_equal "file.txt", r.relative_filepath(path_root + 'folder/subfolder', path_root + "folder/subfolder/file.txt")
  end
  
  def test_relative_filepath_raises_error_if_path_is_not_relative_to_aliased_dir
    assert_raise(RuntimeError) { r.relative_filepath(:dir, "./root/file.txt") }
  end
  
  #
  # translate tests
  #
  
  def test_translate_documentation
    r = Tap::Root.new '/root_dir'
    
    fp = r.filepath(:in, 'path/to/file.txt')    
    assert_equal File.expand_path('/root_dir/in/path/to/file.txt'), fp
    assert_equal File.expand_path('/root_dir/out/path/to/file.txt'), r.translate(fp, :in, :out) 
  end
  
  def test_translate
    assert_equal File.expand_path("./root/another/file.txt"), r.translate("./root/dir/file.txt", :dir, :another)
    assert_equal File.expand_path("./root/another/nested/file.txt"), r.translate("./root/dir/nested/file.txt", :dir, :another)
  end
  
  def test_translate_raises_error_if_path_is_not_relative_to_aliased_input_dir
    assert_raise(RuntimeError) { r.translate("./root/dir/file.txt", :not_dir, :another) }
  end
  
  #
  # glob tests
  #
  
  def test_glob_returns_all_files_matching_pattern
    assert_equal Dir.glob(File.join(root_dir, '*')),  tr.glob(:root, "*")  
    assert_equal Dir.glob(File.join(root_dir, '*.txt')),  tr.glob(:root, "*.txt")  
    assert_equal Dir.glob(File.join(root_dir, 'lib/*')),  tr.glob(:lib, "*")  
  end

  def test_default_glob_pattern_is_all_files_and_folders
    assert_equal Dir.glob(File.join(root_dir, '**/*')),  tr.glob(:root)
  end
  
  def test_glob_using_multiple_patterns            
    yml_files = Dir.glob(File.join(root_dir, '**/*.yml'))
    txt_files = Dir.glob(File.join(root_dir, '**/*.txt'))
    
    assert_equal(
      (yml_files + txt_files).sort, 
      tr.glob(:root, "**/*.yml", "**/*.txt").sort)
  end
    
  #
  # vglob tests
  #
  
  def test_vglob_returns_all_versions_matching_file_and_version_pattern
    assert_equal 4, Dir.glob(File.join(root_dir, 'versions/*')).length
    
    assert_equal 3, Dir.glob(File.join(root_dir, 'versions/file*.yml')).length
    assert_equal Dir.glob(File.join(root_dir, 'versions/file*.yml')).sort, tr.vglob(:versions, 'file.yml', '*').sort
    
    assert_equal 2, Dir.glob(File.join(root_dir, 'versions/file-0.1*.yml')).length
    assert_equal Dir.glob(File.join(root_dir, 'versions/file-0.1*.yml')).sort, tr.vglob(:versions, 'file.yml', "0.1*").sort
    
    assert_equal 1, Dir.glob(File.join(root_dir, 'versions/file-0.1.yml')).length
    assert_equal Dir.glob(File.join(root_dir, 'versions/file-0.1.yml')).sort, tr.vglob(:versions, 'file.yml', "0.1").sort
    
    assert_equal 0, Dir.glob(File.join(root_dir, 'versions/file-2.yml')).length
    assert_equal [], tr.vglob(:versions, 'file.yml', "2")
  end
  
  def test_default_vglob_pattern_is_all_versions
    expected = Dir.glob(File.join(root_dir, 'versions/file-*.yml')) + [File.join(root_dir, 'versions/file.yml')]
    assert_equal expected.sort, tr.vglob(:versions, 'file.yml').sort
  end
  
  def test_nil_vglob_pattern_matches_the_no_version_file
    assert_equal [File.join(root_dir, 'versions/file.yml')], tr.vglob(:versions, 'file.yml', nil)
    assert_equal [File.join(root_dir, 'versions/file.yml')], tr.vglob(:versions, 'file.yml', '')
  end
  
  def test_vglob_using_multiple_verson_patterns            
    expected = [
      File.join(root_dir, 'versions/file-0.1.2.yml'),
      File.join(root_dir, 'versions/file-0.1.yml')]
    
    assert_equal expected.sort, tr.vglob(:versions, "file.yml", "0.1.2", "0.1").sort
  end
  
  def test_vglob_filters_for_unique_files      
    expected = [File.join(root_dir, 'versions/file-0.1.2.yml')]
    
    assert_equal expected, tr.vglob(:versions, "file.yml", "0.1.2", "0.1.*")
  end
  
  #
  # benchmarks
  #
  
  def test_get_speed
    benchmark_test(20) do |x|
      n = 10000    
      x.report("10k root[] ") { n.times { r[:dir] } }
      x.report("10k root[path_root] ") { n.times { r[ path_root + "path/to/file.txt" ] } }
    end
  end
end