require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/test/file_methods'

class FileMethodsTest < Test::Unit::TestCase
  include Tap::Test::FileMethods
  
  self.test_root = Tap::Root.new(
    __FILE__.chomp("_test.rb"), 
    {:input => 'input', :output => 'output', :expected => 'expected'})
  
  #
  # method_name_str test
  #
  
  def test_method_name_str_returns_test_method_name1
    assert_equal "test_method_name_str_returns_test_method_name1", method_name_str  
  end
  
  def test_method_name_str_returns_test_method_name2
    assert_equal "test_method_name_str_returns_test_method_name2", method_name_str  
  end
  
  #
  # method_root test
  #
  
  def test_method_root_is_a_duplicate_of_test_root_reconfigured_to_method_name_dir
    assert method_root.kind_of?(Tap::Root)
    
    test_root_config = ctr.config.to_hash
    test_root_config[:root] = ctr[method_name_str]
    assert_equal test_root_config, method_root.config.to_hash
  end
  
  #
  # make_test_directories test
  #
  
  def test_make_test_directories 
    root = File.expand_path( __FILE__.chomp("_test.rb")  + "/test_make_test_directories")
    begin
      assert_equal root, method_root[:root]
      assert_equal({
          :input => 'input', 
          :output => 'output', 
          :expected => 'expected'}, method_root.directories)
      
      method_root.directories.values.each do |dir|
        assert !File.exists?(method_root[dir]), dir
      end
      
      make_test_directories
   
      method_root.directories.values.each do |dir|
        assert File.exists?(method_root[dir]), dir
      end
    ensure
      FileUtils.rm_r root if File.exists?(root)
    end
  end

  # #
  # # method_tempfile test
  # #
  # 
  # def test_method_tempfile_returns_new_file_in_output_dir
  #   output_root = File.join(trs.root, method_name_str, "output")
  #   
  #   filepath1 =File.join(output_root, "file#{$$}.0")
  #   assert_equal filepath1, method_tempfile('file')
  #   
  #   filepath2 = File.join(output_root,  "file#{$$}.1")
  #   assert_equal filepath2, method_tempfile('file')
  #   
  #   assert_equal [filepath1, filepath2], method_tempfiles
  # end
  
  #
  # assert_files
  #
  
  def setup_file(dir, path, content)
    path = method_root.filepath(dir, path)
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
        target = method_root.filepath(:output, File.basename(input_file))
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
          target = method_root.filepath(:output, File.basename(input_file))
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
          target = method_root.filepath(:output, File.basename(input_file))
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
          target = method_root.filepath(:output, File.basename(input_file))
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
  
  def test_assert_files_translates_reference_files_to_reference_dir
    setup_file :input, "one.txt.ref", ""
    setup_file :input, "two.txt.ref", ""
    setup_file :ref, "one.txt", "file one"
    setup_file :ref, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file one"
    setup_file :expected, "two.txt", "processed file two"
    
    assert_files :reference_dir => method_root[:ref] do |input_files|
      input_files.collect do |input_file|
        target = method_root.filepath(:output, File.basename(input_file))
        File.open(target, "w") do |file|
          file << "processed "
          file << File.read(input_file)
        end
        target
      end
    end
  end
end

class FileTestTestWithOptions < Test::Unit::TestCase
  acts_as_file_test :root => "some/root/dir"
  
  def test_test_setup
    assert_equal File.expand_path("some/root/dir"), ctr[:root]
    assert_equal({
        :input => 'input', 
        :output => 'output', 
        :expected => 'expected'}, ctr.directories)
  end
end

