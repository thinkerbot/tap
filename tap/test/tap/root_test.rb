require File.join(File.dirname(__FILE__), '../tap_test_helper') 
require 'tap/root'

class RootTest < Test::Unit::TestCase
  Root = Tap::Root
  
  attr_reader :root, :dir
  
  def setup
    @root = Root.new('dir')
    @dir = File.expand_path('dir')
  end
  
  def root_dir
    @root_dir ||= File.expand_path( __FILE__.chomp('.rb') )
  end
  
  #
  # Root.type test
  #
  
  def test_root_type_returns_correct_value_on_various_platforms
    case
    when RUBY_PLATFORM =~ /mswin/
      assert_equal :win, Root.type
    when File.expand_path(".")[0] == ?/
      assert_equal :nix, Root.type
    else
      assert_equal :unknown, Root.type
    end
  end
  
  #
  # initialize test
  #
  
  def test_initialize_expands_path
    root = Root.new('path')
    assert_equal File.expand_path('path'), root.path
  end
  
  def test_initialize_expands_path_relative_to_dir
    root = Root.new('path', 'dir')
    assert_equal File.expand_path('path', 'dir'), root.path
  end
  
  def test_initialize_stringifies_path_and_dir
    root = Root.new(:path, :dir)
    assert_equal File.expand_path('path', 'dir'), root.path
  end
  
  #
  # expand test
  #
  
  def test_expand_expands_path_relative_to_root_path
    assert_equal File.expand_path('path', 'dir'), root.expand('path')
  end
  
  def test_expand_stringifies_paths
    assert_equal File.expand_path('path', 'dir'), root.expand(:path)
  end
  
  #
  # path test
  #
  
  def test_path_joins_and_expands_path_segments_relative_to_root_path
    assert_equal File.expand_path('path/to/file', 'dir'), root.path('path', 'to', 'file')
  end
  
  def test_path_stringifies_segments
    assert_equal File.expand_path('path/to/file', 'dir'), root.path('path', :to, 'file')
  end
  
  #
  # relative test
  #
  
  def test_relative_is_true_if_the_expanded_path_is_relative_to_root
    assert_equal true, root.relative?('path')
    assert_equal true, root.relative?(File.join(dir, 'path'))
    assert_equal false, root.relative?('path/../..')
    assert_equal false, root.relative?(File.expand_path('/alt/path'))
  end
  
  #
  # relative_path test
  #
  
  def test_relative_path_returns_path_relative_to_root
    path = File.expand_path('path/to/file', dir)
    assert_equal 'path/to/file', root.relative_path(path)
  end
  
  def test_relative_path_returns_empty_string_for_root_path
    assert_equal '', root.relative_path(dir)
  end
  
  def test_relative_path_returns_nil_for_non_relative_paths
    assert_equal nil, root.relative_path('path/../..')
    assert_equal nil, root.relative_path(File.expand_path('/alt/path'))
  end
  
  def test_relative_path_works_for_root_dir
    root = Root.new('/')
    assert_equal 'path/to/file', root.relative_path('/path/to/file')
  end
  
  #
  # root test
  #
  
  def test_root_returns_new_root_relative_to_self
    rt = root.root('path')
    assert_equal Root, rt.class
    assert_equal File.expand_path('path', dir), rt.path
  end
  
  #
  # sub test
  #
  
  def test_sub_returns_new_root_relative_to_self
    rt = root.sub('path')
    assert_equal Root, rt.class
    assert_equal File.expand_path('path', dir), rt.path
  end
  
  def test_sub_raises_error_for_non_sub_path
    err = assert_raises(ArgumentError) { root.sub('path/../..') }
    
    sub = File.expand_path('path/../..', dir)
    assert_equal "not a sub path: #{sub} (#{dir})", err.message
  end
  
  #
  # parent test
  #
  
  def test_parent_returns_root_for_parent_directory
    parent = root.parent
    assert_equal File.dirname(dir), parent.path
  end
  
  #
  # exchange test
  #
  
  def test_exchange_exchanges_extname
    assert_equal File.expand_path('path.html', dir), root.exchange('path.txt', '.html')
    assert_equal File.expand_path('path.rb', dir), root.exchange('path.txt', 'rb')
  end
  
  #
  # translate test
  #
  
  def test_translate_translates_path_from_source_to_target
    assert_equal File.expand_path('alt/to/file.txt', dir), root.translate("path/to/file.txt", "path", "alt")
  end

  def test_translate_raises_error_if_path_is_not_relative_to_source
    err = assert_raises(ArgumentError) { root.translate("path/to/file.txt", "alt", "path") }
    
    path = File.expand_path('path/to/file.txt', dir)
    source = File.expand_path('alt', dir)
    assert_equal "\n#{path}\nis not relative to:\n#{source}", err.message
  end
  
  #
  # glob tests
  #

  def test_glob_returns_all_unique_files_matching_patterns
    root = Root.new(root_dir)
    
    one = File.expand_path('one.txt', root_dir)
    two = File.expand_path('two.txt', root_dir)
    three = File.expand_path('three.rb', root_dir)
    
    assert_equal [one, two, three].sort, root.glob.sort  
    assert_equal [one, two, three].sort, root.glob("*").sort  
    assert_equal [one, two].sort, root.glob("*.txt").sort  
    assert_equal [one, two, three].sort, root.glob("*.txt", "*.rb").sort    
  end

  #
  # chdir test
  #
  
  def test_chdir_chdirs_to_dir_if_no_block_is_given
    pwd = File.expand_path(Dir.pwd)
    assert pwd != root_dir
    
    begin
      root.chdir(root_dir)
      assert_equal root_dir, File.expand_path(Dir.pwd)
    ensure
      Dir.chdir(pwd)
    end
  end
  
  def test_chdir_executes_block_in_the_specified_directory
    pwd = File.expand_path(Dir.pwd)
    assert pwd != root_dir
    
    was_in_block = false
    begin
      res = root.chdir(root_dir) do 
        was_in_block = true
        assert_equal root_dir, File.expand_path(Dir.pwd)
        "result"
      end
      
      assert_equal true, was_in_block
      assert_equal "result", res
      assert_equal pwd, File.expand_path(Dir.pwd)
    ensure
      Dir.chdir(pwd)
    end
  end
  
  def test_chdir_raises_error_for_non_dir_inputs
    path = File.join(root_dir, 'one.txt')
    pwd = File.expand_path(Dir.pwd)
    
    assert File.file?(path)
    begin
      err = assert_raises(ArgumentError) { root.chdir(path) }
      assert_equal "not a directory: #{path}", err.message
    ensure
      Dir.chdir(pwd)
    end
  end
  
  def test_chdir_creates_directory_if_specified
    dir = File.join(root_dir, 'dir')
    pwd = File.expand_path(Dir.pwd)
    
    assert_equal false, File.exists?(dir)
    begin
      root.chdir(dir, true)
      assert_equal true, File.directory?(dir)
      assert_equal dir, File.expand_path(Dir.pwd)
    ensure
      Dir.chdir(pwd)
      FileUtils.rm_r(dir) if File.exists?(dir)
    end
  end
  
  #
  # open test
  #
  
  def test_open_opens_file_with_File_open_semantics
    root = Root.new(root_dir)
    assert_equal 'one', root.open('one.txt').read
    
    result = root.open('one.txt') do |io|
      assert_equal 'one', io.read
      :result
    end
    assert_equal :result, result
  end
  
  #
  # prepare test
  #
  
  #
  # prepare test
  #
  
  def test_prepares_makes_parent_directory_of_path
    root = Root.new(root_dir)
    non_dir = File.join(root_dir, 'non')
    
    assert_equal false, File.exists?(non_dir)
    begin
      path = File.join(root_dir, 'non/existant/path')
      assert_equal path, root.prepare('non/existant/path')
      assert_equal false, File.exists?(path)
      assert_equal true, File.exists?(File.dirname(path))
    ensure
      FileUtils.rm_r(non_dir) if File.exists?(non_dir)
    end
  end
  
  def test_prepare_creates_file_and_passes_it_to_block_if_given
    root = Root.new(root_dir)
    path = File.join(root_dir, 'path')
    
    assert_equal false, File.exists?(path)
    begin
      root.prepare('path') {|io| io << "content"}
      assert_equal "content", File.read(path) 
    ensure
      FileUtils.rm_r(path) if File.exists?(path)
    end
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_path
    assert_equal root.path, root.to_s
  end
end