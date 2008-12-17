require File.join(File.dirname(__FILE__), 'tap_test_helper.rb') 
require 'tap/root'

class RootTest < Test::Unit::TestCase
  include Tap::Test::SubsetTest
  
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
  
  def test_class_relative_filepath_empty_string_if_path_is_dir
    assert_equal '', Tap::Root.relative_filepath('dir', 'dir')
  end
    
  def test_class_relative_filepath_returns_nil_if_path_is_not_relative_to_dir
    assert_nil Tap::Root.relative_filepath('dir', "./root/file.txt")
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
  # Tap::Root translate test
  #
  
  def test_class_translate_documentation
    assert_equal  '/another/path/to/file.txt', Tap::Root.translate("/path/to/file.txt", "/path", "/another/path")
  end

  def test_translate_raises_error_if_path_is_not_relative_to_source_dir
    assert_raise(ArgumentError) { Tap::Root.translate("/path/to/file.txt", "/not_path", "/another/path") }
  end
  
  #
  # Tap::Root exchange test
  #
  
  def test_class_exchange_documentation
    assert_equal 'path/to/file.html', Tap::Root.exchange('path/to/file.txt', '.html')
    assert_equal 'path/to/file.rb', Tap::Root.exchange('path/to/file.txt', 'rb')
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
  # Tap::Root sglob test
  #
  
  def test_sglob_returns_all_paths_matching_the_suffix_pattern
    base_one = File.join(root_dir, 'sglob/base_one')
    base_two = File.join(root_dir, 'sglob/base_two')
    
    one = File.join(base_one, 'one.txt')
    two = File.join(base_one, 'two.txt')
    _one = File.join(base_two, 'one.txt')
    _dir = File.join(base_two, 'dir')
    _two = File.join(base_two, 'dir/two.txt')
    
    [one, two, _one, _dir, _two].each {|path| assert File.exists?(path) }
    
    assert_equal [one, two, _dir, _one].sort, Tap::Root.sglob("*", base_one, base_two).sort
    assert_equal [_dir, _one, _two].sort, Tap::Root.sglob("**/*", base_two).sort
    assert_equal [one, _one].sort, Tap::Root.sglob("*one*", base_one, base_two).sort
  end
  
  def test_sglob_returns_empty_array_for_no_base_paths
    assert_equal [], Tap::Root.sglob("**/*")
  end
  
  #
  # Tap::Root chdir test
  #
  
  def test_chdir_chdirs_to_dir_if_no_block_is_given
    test_dir = root_dir
    pwd = File.expand_path(Dir.pwd)
    
    assert_not_equal pwd, test_dir
    assert File.directory?(test_dir)
    
    begin
      Tap::Root.chdir(test_dir)
      assert_equal test_dir, File.expand_path(Dir.pwd)
    ensure
      Dir.chdir(pwd)
    end
    
    assert_equal pwd, File.expand_path(Dir.pwd)
  end
  
  def test_chdir_executes_block_in_the_specified_directory
    test_dir = root_dir
    pwd = File.expand_path(Dir.pwd)
    
    assert_not_equal pwd, test_dir
    assert File.directory?(test_dir)
    
    was_in_block = false
    begin
      res = Tap::Root.chdir(test_dir) do 
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
    filepath = root_dir + '/file.txt'
    pwd = File.expand_path(Dir.pwd)

    assert !File.exists?(root_dir + '/non')
    assert File.exists?(filepath) 
    assert File.file?(filepath)
    begin
      assert_raise(ArgumentError) { Tap::Root.chdir(filepath) {} }
      assert_raise(ArgumentError) { Tap::Root.chdir(filepath) {} }
    ensure
      Dir.chdir(pwd)
    end
    
    assert_equal pwd, File.expand_path(Dir.pwd)
  end
  
  def test_chdir_creates_directory_if_specified
    test_dir = root_dir + '/non/existant/dir'
    pwd = File.expand_path(Dir.pwd)
    
    assert_not_equal pwd, test_dir
    assert !File.exists?(root_dir + '/non')

    was_in_block = false
    begin
      Tap::Root.chdir(test_dir, true) do 
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
  # Tap::Root prepare test
  #
  
  def test_class_prepares_makes_parent_directory_of_path
    path = root_dir + '/non/existant/path'
    assert !File.exists?(root_dir + '/non')
    begin
      assert_equal path, Tap::Root.prepare(path)
      assert !File.exists?(path)
      assert File.exists?(File.dirname(path))
    ensure
      FileUtils.rm_r(root_dir + '/non') if File.exists?(root_dir + '/non')
    end
  end
  
  def test_class_prepare_creates_file_and_passes_it_to_block_if_given
    path = root_dir + '/non/existant/path'
    assert !File.exists?(root_dir + '/non')
    begin
      assert_equal path, Tap::Root.prepare(path) {|file| file << "content" }
      assert File.exists?(path)
      assert_equal "content", File.read(path)
    ensure
      FileUtils.rm_r(root_dir + '/non') if File.exists?(root_dir + '/non')
    end
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
  # Tap::Root expanded? test
  #

  def test_expanded_documentation
    assert Tap::Root.expanded?("C:/path", :win)
    assert Tap::Root.expanded?("c:/path", :win)
    assert Tap::Root.expanded?("D:/path", :win)
    assert !Tap::Root.expanded?("path", :win)

    assert Tap::Root.expanded?('/path', :nix)
    assert !Tap::Root.expanded?('path', :nix)
  end
  
  def test_expanded
    assert Tap::Root.expanded?("C:/path", :win)
    assert Tap::Root.expanded?("c:/path", :win)
    assert Tap::Root.expanded?("D:/path", :win)
    assert !Tap::Root.expanded?("/path", :win)
    assert !Tap::Root.expanded?("path", :win)

    assert Tap::Root.expanded?("/path", :nix)
    assert !Tap::Root.expanded?("C:/path", :nix)
    assert !Tap::Root.expanded?("path", :nix)
    
    assert_nil Tap::Root.expanded?("C:/path", :other)
    assert_nil Tap::Root.expanded?("/path", :other)
    assert_nil Tap::Root.expanded?("path", :other)
  end
  
  #
  # Tap::Root trivial? test
  #
  
  def test_trivial_returns_true_for_nil_path
    assert_equal true, Tap::Root.trivial?(nil)
  end
  
  def test_trivial_returns_true_for_non_existant_path
    assert !File.exists?("non-existant-file.txt")
    assert_equal true, Tap::Root.trivial?("non-existant-file.txt")
  end
  
  def test_trivial_returns_true_for_directory
    path = File.dirname(__FILE__)
    assert File.directory?(path)
    assert_equal true, Tap::Root.trivial?(path)
  end
  
  def test_trivial_returns_true_for_empty_files
    path = File.join(root_dir, "file.txt")
    assert File.exists?(path)
    assert_equal 0, File.size(path)
    assert_equal true, Tap::Root.trivial?(path)
  end
  
  def test_trivial_returns_false_for_non_empty_files
    assert_equal false, Tap::Root.trivial?(__FILE__)
  end
  
  #
  # Tap::Root empty? test
  #
  
  def test_empty_returns_true_if_the_directory_has_no_files_or_does_not_exist
    dir = root_dir + '/dir'
    assert !File.exists?(dir)
    assert Tap::Root.empty?(dir)
    
    begin
      FileUtils.mkdir(dir) 
      assert Tap::Root.empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_detects_files
    dir = root_dir + '/dir'
    begin
      FileUtils.mkdir(dir) 
      assert Tap::Root.empty?(dir)
      
      FileUtils.touch(dir + '/file.txt')
      assert !Tap::Root.empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_detects_hidden_files
    dir = root_dir + '/dir'
    begin
      FileUtils.mkdir(dir) 
      assert Tap::Root.empty?(dir)
      
      FileUtils.touch(dir + '/.hidden_file')
      assert !Tap::Root.empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_detects_folders
    dir = root_dir + '/dir'
    begin
      FileUtils.mkdir(dir) 
      assert Tap::Root.empty?(dir)
      
      FileUtils.mkdir(dir + '/sub_dir')
      assert !Tap::Root.empty?(dir)
    ensure
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  def test_empty_returns_true_for_nil
    assert Tap::Root.empty?(nil)
  end
  
  #
  # Tap::Root.minimize test
  #
  
  def test_minimize_documentation
    assert_equal ['a', 'b'], Tap::Root.minimize(['path/to/a.rb', 'path/to/b.rb'])
    assert_equal ['a', 'b'], Tap::Root.minimize(['path/to/a-0.1.0.rb', 'path/to/b-0.1.0.rb'])
    assert_equal ['file.rb', 'file.txt'], Tap::Root.minimize(['path/to/file.rb', 'path/to/file.txt'])
    assert_equal ['path-0.1/to/file', 'path-0.2/to/file'], Tap::Root.minimize(['path-0.1/to/file.rb', 'path-0.2/to/file.rb'])
    assert_equal ['a-0.1.0.rb', 'a-0.1.0.txt'], Tap::Root.minimize(['path/to/a-0.1.0.rb', 'path/to/a-0.1.0.txt'])
    assert_equal ['a-0.1.0', 'a-0.2.0'], Tap::Root.minimize(['path/to/a-0.1.0.rb', 'path/to/a-0.2.0.rb'])
  end
  
  def test_minimize_collects_unique_basenames_for_paths
    # some extreme cases
    assert_equal [], Tap::Root.minimize([])
    assert_equal ['a'], Tap::Root.minimize(['a.txt'])
    assert_equal ['a'], Tap::Root.minimize(['a.txt', 'a.txt'])
    
    # cases where extname and version is dropped
    assert_equal ['c', 'C'], Tap::Root.minimize(['a/b/c.txt', 'a/b/C.txt'])  
    assert_equal ['c', 'C'], Tap::Root.minimize(['a/b/c.txt', 'a/b/C.rb'])  
    assert_equal ['c', 'C'], Tap::Root.minimize(['a/b/c-0.1.txt', 'a/b/C-0.1.txt'])  
    assert_equal ['c', 'C'], Tap::Root.minimize(['a/b/c-0.1.txt', 'a/b/C-0.2.txt']) 
    
    assert_equal ['b/c', 'B/c'], Tap::Root.minimize(['a/b/c.txt', 'a/B/c.txt'])  
    assert_equal ['b/c', 'B/c'], Tap::Root.minimize(['a/b/c.txt', 'a/B/c.rb'])  
    assert_equal ['b/c', 'B/c'], Tap::Root.minimize(['a/b/c-0.1.txt', 'a/B/c-0.1.txt'])  
    assert_equal ['b/c', 'B/c'], Tap::Root.minimize(['a/b/c-0.1.txt', 'a/B/c-0.2.txt'])
    
    assert_equal ['a/b/c', 'A/b/c'], Tap::Root.minimize(['a/b/c.txt', 'A/b/c.txt'])  
    assert_equal ['a/b/c', 'A/b/c'], Tap::Root.minimize(['a/b/c.txt', 'A/b/c.rb'])  
    assert_equal ['a/b/c', 'A/b/c'], Tap::Root.minimize(['a/b/c-0.1.txt', 'A/b/c-0.1.txt'])  
    assert_equal ['a/b/c', 'A/b/c'], Tap::Root.minimize(['a/b/c-0.1.txt', 'A/b/c-0.2.txt'])
    
    assert_equal ['b-0.1/c', 'b-0.2/c'], Tap::Root.minimize(['a/b-0.1/c.txt', 'a/b-0.2/c.txt'])  
    assert_equal ['a/b-0.1/c', 'A/b-0.1/c'], Tap::Root.minimize(['a/b-0.1/c.txt', 'A/b-0.1/c.rb'])  
    assert_equal ['b-0.1/c', 'b-0.2/c'], Tap::Root.minimize(['a/b-0.1/c-0.1.txt', 'a/b-0.2/c-0.1.txt'])  
    assert_equal ['a/b-0.1/c', 'A/b-0.1/c'], Tap::Root.minimize(['a/b-0.1/c-0.1.txt', 'A/b-0.1/c-0.2.txt'])
    
    # cases where version is kept
    assert_equal ['c-0.1', 'c-0.2'], Tap::Root.minimize(['a/b/c-0.1.txt', 'a/b/c-0.2.txt'])  
    assert_equal ['c-0.1', 'c-0.2'], Tap::Root.minimize(['a/b/c-0.1.txt', 'a/b/c-0.2.rb'])  
    assert_equal ['c-0.1', 'c-0.2'], Tap::Root.minimize(['a/b/c-0.1', 'a/b/c-0.2'])  
    assert_equal ['c-0.1', 'c-0.2'], Tap::Root.minimize(['a/b/c-0.1', 'a/b/c-0.2'])
    
    # cases where ext is kept
    assert_equal ['c.txt', 'c.rb'], Tap::Root.minimize(['a/b/c.txt', 'a/b/c.rb'])  
    assert_equal ['c-0.1.txt', 'c-0.1.rb'], Tap::Root.minimize(['a/b/c-0.1.txt', 'a/b/c-0.1.rb'])

    # a complex case
    paths = %w{
      a/b/c.d
      a/b/c.d
      a/b/C.d
      a/b/c.D
      a/B/c.d
      A/b/c.d
      
      a/b-0.1/c.d
      a/b-0.2/c.d
      a/b/c-0.1.d
      a/b/c-0.2.d
    }
    
    expected = %w{
      c.d
      c.D
      C
      B/c
      A/b/c
      b-0.1/c
      b-0.2/c
      c-0.1
      c-0.2
    }
    
    assert_equal expected.sort, Tap::Root.minimize(paths).sort
    
    # special cases where order is important so that all paths
    # can be identified.  (if the order were ['b/c', 'c', 'a/b/c'],  
    # then no linear minimal_match lookup could select c)
    assert_equal ['c', 'b/c', 'a/b/c'], Tap::Root.minimize(['b/c', 'a/b/c', 'c'])  
    assert_equal ['c', 'b/c', 'a/b/c'], Tap::Root.minimize(['b/c', 'c', 'a/b/c']) 
    assert_equal ['c', 'b/c', 'a/b/c'], Tap::Root.minimize(['c', 'a/b/c', 'b/c'])
    assert_equal ['c', 'b/c', 'a/b/c'], Tap::Root.minimize(['a/b/c', 'c', 'b/c'])  
     
    # note in these cases the order of '/b/c' and '/a/b/c' can be reversed
    # safely, because each minimized paths still can be identified in order
    # ('a/b/c' and '/b/c'do not conflict)
    assert_equal ['/c', '/b/c', 'a/b/c'], Tap::Root.minimize(['/b/c', '/a/b/c', '/c'])  
    assert_equal ['/c', '/b/c', 'a/b/c'], Tap::Root.minimize(['/b/c', '/c', '/a/b/c']) 
    assert_equal ['/c', 'a/b/c', '/b/c'], Tap::Root.minimize(['/c', '/a/b/c', '/b/c'])
    assert_equal ['/c', 'a/b/c', '/b/c'], Tap::Root.minimize(['/a/b/c', '/c', '/b/c'])  
  end
  
  def test_minimize_speed
    benchmark_test(30) do |x|  
      paths = (0..100).collect {|i| "path#{i}/to/file"}
      x.report("100 dir paths ") { Tap::Root.minimize(paths) }
      
      paths = (0..1000).collect {|i| "path#{i}/to/file"}
      x.report("1k dir paths") { Tap::Root.minimize(paths) }
      
      paths = (0..100).collect {|i| "path/to/file#{i}"}
      x.report("100 file paths ") { Tap::Root.minimize(paths) }
      
      paths = (0..1000).collect {|i| "path/to/file#{i}"}
      x.report("1k file paths") { Tap::Root.minimize(paths) }
    end
  end
  
  #
  # Tap::Root.minimal_match? test
  #
  
  def test_minimal_match_documentation
    assert Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file')
    assert Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'dir/file')
    assert Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0')
    assert Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file-0.1.0.rb') 
  
    assert !Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file.rb')
    assert !Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'file-0.2.0') 
    assert !Tap::Root.minimal_match?('dir/file-0.1.0.rb', 'another')
  
    assert Tap::Root.minimal_match?('dir/file-0.1.0.txt', 'file')
    assert !Tap::Root.minimal_match?('dir/file-0.1.0.txt', 'ile') 
    assert Tap::Root.minimal_match?('dir/file-0.1.0.txt', 'r/file')     
  end
  
  def test_minimal_match
    assert Tap::Root.minimal_match?('a/b/c.d', 'c')
    assert Tap::Root.minimal_match?('a/b/c.d', 'b/c')
    assert Tap::Root.minimal_match?('a/b/c.d', 'a/b/c')
    assert Tap::Root.minimal_match?('a/b/c.d', 'c.d')
    assert Tap::Root.minimal_match?('a/b/c.d', 'b/c.d')
    assert Tap::Root.minimal_match?('a/b/c.d', 'a/b/c.d')
    
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'c')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'b/c')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'a/b/c')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'c-0.1')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'b/c-0.1')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'a/b/c-0.1')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'c-0.1.d')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'b/c-0.1.d')
    assert Tap::Root.minimal_match?('a/b/c-0.1.d', 'a/b/c-0.1.d')
    
    assert Tap::Root.minimal_match?('a/b/c-0.0.1', 'c')
    assert Tap::Root.minimal_match?('a/b/c-0.0.1', 'b/c')
    assert Tap::Root.minimal_match?('a/b/c-0.0.1', 'a/b/c')
    assert Tap::Root.minimal_match?('a/b/c-0.0.1', 'c-0.0.1')
    assert Tap::Root.minimal_match?('a/b/c-0.0.1', 'b/c-0.0.1')
    assert Tap::Root.minimal_match?('a/b/c-0.0.1', 'a/b/c-0.0.1')
    
    assert !Tap::Root.minimal_match?('a/b/c.d', 'C')
    assert !Tap::Root.minimal_match?('a/b/c.d', 'B/c')
    assert !Tap::Root.minimal_match?('a/b/c.d', 'A/b/c')
    assert !Tap::Root.minimal_match?('a/b/c.d', 'c.D')
    assert !Tap::Root.minimal_match?('a/b/c-0.1.d', 'c-0.2')
    assert !Tap::Root.minimal_match?('a/b/c-0.1.d', 'c.d')
  end
  
  #
  # Tap::Root.split tests
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
        assert_equal [root_path, "path", "to", "file"], Tap::Root.split('path\to\..\.\to\file')
        assert_equal  ["path", "to", "file"], Tap::Root.split('path/to/.././to/file', false)
      else
        Dir.chdir("/")
        assert_equal '/', Dir.pwd
        assert_equal ["", "path", "to", "file"], Tap::Root.split('path/to/.././to/file')
        assert_equal ["path", "to", "file"], Tap::Root.split('path/to/.././to/file', false)
      end
    ensure
      Dir.chdir(pwd)
    end
  end
  
  def test_split
    assert_equal [root_path], Tap::Root.split("#{root_path}/")
    assert_equal [root_path, "path"], Tap::Root.split("#{root_path}/path")
    assert_equal [root_path, "path", "to", "file.txt"], Tap::Root.split("#{root_path}/path/to/file.txt")
    assert_equal [root_path, "path", "to", "file.txt"], Tap::Root.split("#{root_path}/path/to/././../../path/to/file.txt")
    assert_equal [root_path, "path", "path", "path", "file.txt"], Tap::Root.split("#{root_path}/path/path/path/file.txt")
    
    assert_equal Tap::Root.split(Dir.pwd), Tap::Root.split("")
    assert_equal Tap::Root.split("."), Tap::Root.split("")

    assert_equal [], Tap::Root.split("", false)
    assert_equal [], Tap::Root.split(".", false)
    assert_equal ["path"], Tap::Root.split("path", false)
    assert_equal [root_path, "path"], Tap::Root.split("#{root_path}/path", false)
    assert_equal ["path", "to", "file.txt"], Tap::Root.split("path/to/file.txt", false)
    assert_equal [root_path, "path", "to", "file.txt"], Tap::Root.split("#{root_path}/path/to/file.txt", false)
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
  
  def test_config_is_initialized
    r = Tap::Root.new
    assert_equal({:root => File.expand_path(Dir.pwd), :directories => {}, :absolute_paths => {}}, r.config)
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
  
  def test_relative_filepath_returns_nil_if_path_is_not_relative_to_aliased_dir
    assert_nil r.relative_filepath(:dir, "./root/file.txt")
  end
  
  def test_relative_filepath_returns_empty_string_if_path_is_aliased_dir
    assert_equal '', r.relative_filepath(:dir, r[:dir])
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
    assert_raise(ArgumentError) { r.translate("./root/dir/file.txt", :not_dir, :another) }
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
  # prepare test
  #
  
  def test_prepares_makes_a_filepath_from_the_inputs_and_prepares_it
    path = root_dir + '/non/existant/path'
    assert !File.exists?(root_dir + '/non')
    begin
      assert_equal path, tr.prepare('non', 'existant', 'path') {|file| file << "content"}
      assert File.exists?(path)
      assert_equal "content", File.read(path)
    ensure
      FileUtils.rm_r(root_dir + '/non') if File.exists?(root_dir + '/non')
    end
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