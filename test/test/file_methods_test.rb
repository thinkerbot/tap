require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/test/file_methods'

class FileMethodsTest < Test::Unit::TestCase
  include Tap::Test::SubsetMethods
  acts_as_file_test
  
  def test_method_name_returns_test_method_name1
    assert_equal "test_method_name_returns_test_method_name1", method_name_str  
  end
  
  def test_method_name_returns_test_method_name2
    assert_equal "test_method_name_returns_test_method_name2", method_name_str  
  end
  
  def test_make_test_directories 
    root = File.expand_path(File.join(File.dirname(__FILE__), "file_methods"))
    begin
      assert_equal root, trs[:root]
      assert_equal({
          :input => 'input', 
          :output => 'output', 
          :expected => 'expected'}, trs.directories)
      
      trs.directories.values.each do |dir|
        assert !File.exists?(File.join(root, "test_make_test_directories", dir.to_s)), dir
      end
      
      make_test_directories # alias for make_test_directories
   
      trs.directories.values.each do |dir|
        assert File.exists?(File.join(root, "test_make_test_directories", dir.to_s)), dir
      end
    ensure
      dir =  File.join(File.join(root, "test_make_test_directories"))
      FileUtils.rm_r dir if File.exists?(dir)
    end
  end

  #
  # method filepath tests
  #

  def test_method_dir_adds_method_to_path  
    assert_equal File.join(trs.root, method_name_str, "input"), method_dir(:input)
  end
  
  def test_method_filepath_adds_method_to_path
    input_root = File.join(trs.root, method_name_str, "input")
    assert_equal File.join(input_root, "file.txt"), method_filepath(:input, 'file.txt')
    assert_equal File.join(input_root, "folder/file.txt"), method_filepath(:input, 'folder', 'file.txt')
  end

  #
  # method relative filepath tests
  #

  def test_method_relative_filepath_removes_method_dir  
    input_root = File.join(trs.root, method_name_str, "input")
    assert_equal 'file.txt', method_relative_filepath(:input,  File.join(input_root, "file.txt"))
    assert_equal 'folder/file.txt', method_relative_filepath(:input, File.join(input_root, "folder/file.txt"))
  end

  def test_method_relative_filepath_expands_filepaths
    input_root = File.join(trs.root, method_name_str, "input")
    assert_equal 'file.txt', method_relative_filepath(:input, File.join(input_root, "folder/.././file.txt") )
  end
  
  def test_method_relative_filepath_raises_error_unless_filepath_begins_with_method_dir
    assert_raise(RuntimeError) { method_relative_filepath(:input, File.join('some/path', trs[:input], 'file.txt') ) }
  end
  
  #
  # method translate tests
  #
  
  def test_method_translate
    ['file.txt', 'folder/file.txt'].each do |path|
      filepath = File.join(trs.root, method_name_str, "input", path)
      expected = File.join(trs.root, method_name_str, "output", path)
    
      assert_equal expected, method_translate(filepath, :input, :output)
    end
  end  
  
  #
  # method glob tests
  #
  
  def test_method_glob
    {
      [:expected] => ["file.yml", "file_1.txt", "file_2.txt"],
      [:expected, "*"] => ["file.yml", "file_1.txt", "file_2.txt"],
      [:expected, "*.txt"] => ["file_1.txt", "file_2.txt"],
      [:expected, "*.txt", "*.yml"] => ["file.yml", "file_1.txt", "file_2.txt"]
    }.each_pair do |testcase, expected|
      expected.collect! { |file| method_filepath(:expected, file) }
      
      assert_equal expected.sort, method_glob(*testcase).sort
    end
  end  
  
  #
  # method_tempfile test
  #
  
  def test_method_tempfile_returns_new_file_in_output_dir
    output_root = File.join(trs.root, method_name_str, "output")
    
    filepath1 =File.join(output_root, "file#{$$}.0")
    assert_equal filepath1, method_tempfile('file')
    
    filepath2 = File.join(output_root,  "file#{$$}.1")
    assert_equal filepath2, method_tempfile('file')
    
    assert_equal [filepath1, filepath2], method_tempfiles
  end
  
  #
  # assert_files
  #
  
  def setup_file(dir, path, content)
    path = method_filepath(dir, path)
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir) unless File.exists?(dir)
    
    File.open(path, "w") {|f| f << content}
    path
  end
  
  def test_assert_files
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file one"
    setup_file :expected, "two.txt", "processed file two"
    
    assert_files do |input_files|
      input_files.collect do |input_file|
        target = method_filepath(:output, File.basename(input_file))
        File.open(target, "w") do |file|
          file << "processed "
          file << File.read(input_file)
        end
        target
      end
    end
  end
  
  def test_assert_files_fails_for_missing_expected_file
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file one"
    
    failed = false
    begin
      assert_files do |input_files|
        input_files.collect do |input_file|
          target = method_filepath(:output, File.basename(input_file))
          File.open(target, "w") do |file|
            file << "processed "
            file << File.read(input_file)
          end
          target
        end
      end
    rescue
      failed = true 
    end
    
    assert failed
  end
  
  def test_assert_files_fails_for_missing_output_file
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file one"
    setup_file :expected, "two.txt", "processed file two"
     
    failed = false
    begin
      assert_files do |input_files|
        input_files.collect do |input_file|
          target = method_filepath(:output, File.basename(input_file))
          File.open(target, "w") do |file|
            file << "processed "
            file << File.read(input_file)
          end
          target
        end.first
      end
    rescue
      failed = true 
    end
    
    assert failed
  end
  
  def test_assert_files_fails_for_different_content
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file FLUNK"
    setup_file :expected, "two.txt", "processed file two"
    
    failed = false
    begin
      assert_files do |input_files|
        input_files.collect do |input_file|
          target = method_filepath(:output, File.basename(input_file))
          File.open(target, "w") do |file|
            file << "processed "
            file << File.read(input_file)
          end
          target
        end
      end
    rescue
      failed = true 
    end
    
    assert failed
  end
  
  def test_assert_files_fails_for_no_expected_files
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
   
    was_in_block = false
    failed = false
    begin
      assert_files do |input_files| 
        was_in_block = true
        []
      end
    rescue
      failed = true 
    end
    
    assert failed
    assert !was_in_block
  end
  
  def test_assert_files_can_have_no_expected_files_if_specified
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
   
    was_in_block = false
    assert_files :expected_files => [] do |input_files| 
      assert_equal 2, input_files.length
      was_in_block = true
      []
    end

    assert was_in_block
  end
end

class FileTestTestWithOptions < Test::Unit::TestCase
  acts_as_file_test :root => "some/root/dir"
  
  def test_test_setup
    assert_equal File.expand_path("some/root/dir"), trs[:root]
    assert_equal({
        :input => 'input', 
        :output => 'output', 
        :expected => 'expected'}, trs.directories)
  end
end

