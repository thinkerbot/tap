require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/root/utils'

class RootUtilsTest < Test::Unit::TestCase
  include Tap::Root::Utils
  
  def root_dir 
    File.expand_path(File.join(File.dirname(__FILE__), 'utils'))
  end
  
  def path_root
    path_root = File.expand_path(".")
    while (parent_dir = File.dirname(path_root)) != path_root
      path_root = parent_dir
    end
    
    path_root
  end
  
  #
  # relative path test
  #
  
  def test_relative_path_documentation
    assert_equal "path/to/file.txt", relative_path('dir', "dir/path/to/file.txt")  
  end
  
  def test_relative_path 
    assert_equal "file.txt", relative_path('./root/dir', "./root/dir/file.txt")
    assert_equal "nested/file.txt", relative_path('./root/dir', "./root/dir/nested/file.txt")
  end

  def test_relative_path_expands_paths
    assert_equal "file.txt", relative_path('./root/dir', "./root/folder/.././dir/file.txt")
    assert_equal "file.txt", relative_path('./root/dir', "root/dir/file.txt")
    assert_equal "file.txt", relative_path('root/dir', "./root/dir/file.txt")
    assert_equal "file.txt", relative_path('root/dir', "root/dir/file.txt")
  end
  
  def test_relative_path_does_not_expands_paths_if_dir_string_is_false
    assert_equal nil, relative_path('./root/dir', "./root/folder/.././dir/file.txt", false)
  end
  
  def test_relative_path_empty_string_if_path_is_dir
    assert_equal '', relative_path('dir', 'dir')
  end
    
  def test_relative_path_returns_nil_if_path_is_not_relative_to_dir
    assert_nil relative_path('dir', "./root/file.txt")
  end
  
  def test_relative_path_path_root
    if self.class.match_platform?("mswin")
      assert path_root =~ /^[A-z]:\/$/
      assert_equal "path/to/file.txt", relative_path(path_root, path_root + "path/to/file.txt")
    else
      assert_equal "path/to/file.txt", relative_path(path_root, path_root + "path/to/file.txt")
    end
  end
  
  #
  # translate test
  #
  
  def test_translate_documentation
    assert_equal  '/another/path/to/file.txt', translate("/path/to/file.txt", "/path", "/another/path")
  end

  def test_translate_raises_error_if_path_is_not_relative_to_source_dir
    assert_raises(ArgumentError) { translate("/path/to/file.txt", "/not_path", "/another/path") }
  end
  
  #
  # exchange test
  #
  
  def test_exchange_documentation
    assert_equal 'path/to/file.html', exchange('path/to/file.txt', '.html')
    assert_equal 'path/to/file.rb', exchange('path/to/file.txt', 'rb')
  end

  #
  # glob test
  #
  
  def test_glob_returns_all_unique_files_matching_input_patterns
    files = [root_dir + "/glob/one.txt", root_dir + "/glob/two.txt"]
    
    assert_equal files, glob(root_dir + "/glob/**/*").sort
    assert_equal files, glob(root_dir + "/glob/one.txt", root_dir + "/glob/two.txt").sort
    assert_equal files, glob(root_dir + "/glob/**/*", root_dir + "/glob/one.txt", root_dir + "/glob/two.txt").sort
    assert_equal [], glob(root_dir + "/glob/three.txt")
    assert_equal [], glob()
  end

  #
  # version_glob test
  #
  
  def test_version_glob_returns_all_versions_matching_file_and_version_pattern
    assert_equal 4, Dir.glob(File.join(root_dir, 'version_glob/*')).length

    assert_equal 3, Dir.glob(File.join(root_dir, 'version_glob/file*.yml')).length
    assert_equal Dir.glob(root_dir + '/version_glob/file*.yml').sort, version_glob(root_dir + '/version_glob/file.yml', '*').sort
    
    assert_equal 2, Dir.glob(File.join(root_dir, 'version_glob/file-0.1*.yml')).length
    assert_equal Dir.glob(root_dir + '/version_glob/file-0.1*.yml').sort, version_glob(root_dir + '/version_glob/file.yml', '0.1*').sort
   
    assert_equal 1, Dir.glob(File.join(root_dir, 'version_glob/file-0.1.yml')).length
    assert_equal Dir.glob(root_dir + '/version_glob/file-0.1.yml').sort, version_glob(root_dir + '/version_glob/file.yml', '0.1').sort
    
    assert_equal 0, Dir.glob(File.join(root_dir, 'version_glob/file-2.yml')).length
    assert_equal [], version_glob(root_dir + '/version_glob/file.yml', '2')
  end
  
  def test_default_version_glob_pattern_is_all_versions
    expected = Dir.glob(File.join(root_dir + '/version_glob/file*.yml'))
    assert_equal expected.sort, version_glob(root_dir + '/version_glob/file.yml').sort
  end
  
  #
  # suffix_glob test
  #
  
  def test_suffix_glob_returns_all_paths_matching_the_suffix_pattern
    base_one = File.join(root_dir, 'suffix_glob/base_one')
    base_two = File.join(root_dir, 'suffix_glob/base_two')
    
    one = File.join(base_one, 'one.txt')
    two = File.join(base_one, 'two.txt')
    _one = File.join(base_two, 'one.txt')
    _dir = File.join(base_two, 'dir')
    _two = File.join(base_two, 'dir/two.txt')
    
    [one, two, _one, _dir, _two].each {|path| assert File.exists?(path) }
    
    assert_equal [one, two, _dir, _one].sort, suffix_glob("*", base_one, base_two).sort
    assert_equal [_dir, _one, _two].sort, suffix_glob("**/*", base_two).sort
    assert_equal [one, _one].sort, suffix_glob("*one*", base_one, base_two).sort
  end
  
  def test_suffix_glob_returns_empty_array_for_no_base_paths
    assert_equal [], suffix_glob("**/*")
  end
  
  #
  # chdir test
  #
  
  def test_chdir_chdirs_to_dir_if_no_block_is_given
    test_dir = root_dir
    pwd = File.expand_path(Dir.pwd)
    
    assert pwd != test_dir
    assert File.directory?(test_dir)
    
    begin
      chdir(test_dir)
      assert_equal test_dir, File.expand_path(Dir.pwd)
    ensure
      Dir.chdir(pwd)
    end
    
    assert_equal pwd, File.expand_path(Dir.pwd)
  end
  
  def test_chdir_executes_block_in_the_specified_directory
    test_dir = root_dir
    pwd = File.expand_path(Dir.pwd)
    
    assert pwd != test_dir
    assert File.directory?(test_dir)
    
    was_in_block = false
    begin
      res = chdir(test_dir) do 
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
  
  def test_chdir_raises_error_for_non_dir_inputs
    test_dir = root_dir + '/non/existant/dir'
    path = root_dir + '/file.txt'
    pwd = File.expand_path(Dir.pwd)

    assert !File.exists?(root_dir + '/non')
    assert File.exists?(path) 
    assert File.file?(path)
    begin
      assert_raises(ArgumentError) { chdir(path) {} }
      assert_raises(ArgumentError) { chdir(path) {} }
    ensure
      Dir.chdir(pwd)
    end
    
    assert_equal pwd, File.expand_path(Dir.pwd)
  end
  
  def test_chdir_creates_directory_if_specified
    test_dir = root_dir + '/non/existant/dir'
    pwd = File.expand_path(Dir.pwd)
    
    assert pwd != test_dir
    assert !File.exists?(root_dir + '/non')

    was_in_block = false
    begin
      chdir(test_dir, true) do 
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
  # prepare test
  #
  
  def test_prepares_makes_parent_directory_of_path
    path = root_dir + '/non/existant/path'
    assert !File.exists?(root_dir + '/non')
    begin
      assert_equal path, prepare(path)
      assert !File.exists?(path)
      assert File.exists?(File.dirname(path))
    ensure
      FileUtils.rm_r(root_dir + '/non') if File.exists?(root_dir + '/non')
    end
  end
  
  def test_prepare_creates_file_and_passes_it_to_block_if_given
    path = root_dir + '/non/existant/path'
    assert !File.exists?(root_dir + '/non')
    begin
      assert_equal path, prepare(path) {|file| file << "content" }
      assert File.exists?(path)
      assert_equal "content", File.read(path)
    ensure
      FileUtils.rm_r(root_dir + '/non') if File.exists?(root_dir + '/non')
    end
  end
  
  #
  # path_root_type test
  #
  
  def test_path_root_type
    case
    when self.class.match_platform?("mswin")
      assert_equal :win, path_root_type
    when File.expand_path(".")[0] == ?/
      assert_equal :nix, path_root_type
    else
      assert_equal :unknown, path_root_type
    end
  end
  
  #
  # expanded? test
  #

  def test_expanded_documentation
    assert expanded?("C:/path", :win)
    assert expanded?("c:/path", :win)
    assert expanded?("D:/path", :win)
    assert !expanded?("path", :win)

    assert expanded?('/path', :nix)
    assert !expanded?('path', :nix)
  end
  
  def test_expanded
    assert expanded?("C:/path", :win)
    assert expanded?("c:/path", :win)
    assert expanded?("D:/path", :win)
    assert !expanded?("/path", :win)
    assert !expanded?("path", :win)

    assert expanded?("/path", :nix)
    assert !expanded?("C:/path", :nix)
    assert !expanded?("path", :nix)
    
    assert_nil expanded?("C:/path", :other)
    assert_nil expanded?("/path", :other)
    assert_nil expanded?("path", :other)
  end
  
  #
  # relative? test
  #
  
  def test_relative_returns_true_if_path_is_relative_to_dir
    assert_equal true, relative?('dir', "dir/file.txt")
  end
  
  def test_relative_returns_false_if_path_is_not_relative_to_dir
    assert_equal false, relative?('dir', "./root/file.txt")
  end
  
  def test_relative_expands_paths
    assert_equal true, relative?('dir', "./folder/../dir/file.txt")
    assert_equal false, relative?('dir', "dir/../folder/file.txt")
  end
  
  def test_relative_does_not_expands_paths_if_dir_string_is_false
    assert_equal false, relative?('dir', "./folder/../dir/file.txt", false)
    assert_equal true, relative?('dir', "dir/../folder/file.txt", false)
  end
  
  #
  # trivial? test
  #
  
  def test_trivial_returns_true_for_nil_path
    assert_equal true, trivial?(nil)
  end
  
  def test_trivial_returns_true_for_non_existant_path
    assert !File.exists?("non-existant-file.txt")
    assert_equal true, trivial?("non-existant-file.txt")
  end
  
  def test_trivial_returns_true_for_directory
    path = File.dirname(__FILE__)
    assert File.directory?(path)
    assert_equal true, trivial?(path)
  end
  
  def test_trivial_returns_true_for_empty_files
    path = File.join(root_dir, "file.txt")
    assert File.exists?(path)
    assert_equal 0, File.size(path)
    assert_equal true, trivial?(path)
  end
  
  def test_trivial_returns_false_for_non_empty_files
    assert_equal false, trivial?(__FILE__)
  end
  
  #
  # empty? test
  #
  
  def test_empty_returns_true_if_the_directory_exists_and_has_no_files
    dir = root_dir + '/dir'
    assert !File.exists?(dir)
    begin
      FileUtils.mkdir(dir) 
      assert empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_returns_false_if_the_directory_does_not_exist_or_is_a_file
    dir = root_dir + '/dir'
    assert !File.exists?(dir)
    assert !empty?(dir)
    begin
      FileUtils.touch(dir)
      assert !empty?(dir)
    ensure
      FileUtils.rm(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_detects_files
    dir = root_dir + '/dir'
    assert !File.exists?(dir)
    begin
      FileUtils.mkdir(dir) 
      FileUtils.touch(dir + '/file.txt')
      assert !empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_detects_hidden_files
    dir = root_dir + '/dir'
    assert !File.exists?(dir)
    begin
      FileUtils.mkdir(dir) 
      FileUtils.touch(dir + '/.hidden_file')
      assert !empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_detects_folders
    dir = root_dir + '/dir'
    assert !File.exists?(dir)
    begin
      FileUtils.mkdir(dir)
      FileUtils.mkdir(dir + '/sub_dir')
      assert !empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  #
  # split tests
  #
  
  if match_platform?("mswin")
    root_path = File.expand_path(".")
    while (parent_dir = File.dirname(root_path)) != root_path
      root_path = parent_dir
    end
    ROOT_PATH = root_path.chomp("/")
  else
    ROOT_PATH = ""
  end
  
  def root_path
    ROOT_PATH
  end
  
  def test_split_doc
    pwd = Dir.pwd
    begin
      if self.class.match_platform?("mswin")
        Dir.chdir(root_path + "/")
        assert Dir.pwd =~ /^[A-Z]:\/$/
        assert_equal [root_path, "path", "to", "file"], split('path\to\..\.\to\file')
        assert_equal  ["path", "to", "file"], split('path/to/.././to/file', false)
      else
        Dir.chdir("/")
        assert_equal '/', Dir.pwd
        assert_equal ["", "path", "to", "file"], split('path/to/.././to/file')
        assert_equal ["path", "to", "file"], split('path/to/.././to/file', false)
      end
    ensure
      Dir.chdir(pwd)
    end
  end
  
  def test_split
    assert_equal [root_path], split("#{root_path}/")
    assert_equal [root_path, "path"], split("#{root_path}/path")
    assert_equal [root_path, "path", "to", "file.txt"], split("#{root_path}/path/to/file.txt")
    assert_equal [root_path, "path", "to", "file.txt"], split("#{root_path}/path/to/././../../path/to/file.txt")
    assert_equal [root_path, "path", "path", "path", "file.txt"], split("#{root_path}/path/path/path/file.txt")
    
    assert_equal split(Dir.pwd), split("")
    assert_equal split("."), split("")

    assert_equal [], split("", false)
    assert_equal [], split(".", false)
    assert_equal ["path"], split("path", false)
    assert_equal [root_path, "path"], split("#{root_path}/path", false)
    assert_equal ["path", "to", "file.txt"], split("path/to/file.txt", false)
    assert_equal [root_path, "path", "to", "file.txt"], split("#{root_path}/path/to/file.txt", false)
  end
  
end