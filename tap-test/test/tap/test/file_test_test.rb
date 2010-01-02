require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test/file_test'

class FileTestTest < Test::Unit::TestCase
  include Tap::Test::FileTest
  
  ASSERTION_ERROR = Object.const_defined?(:MiniTest) ? MiniTest::Assertion : Test::Unit::AssertionFailedError
  
  self.class_test_root = Tap::Root.new(:root => __FILE__.chomp("_test.rb"))
  self.cleanup_dirs = [:output]
  
  #
  # method_root test
  #
  
  def test_method_root_is_a_duplicate_of_test_root_reconfigured_to_method_name_dir
    assert method_root.kind_of?(Tap::Root)
    
    test_root_config = ctr.config.to_hash
    test_root_config[:root] = ctr[method_name.to_sym]
    assert_equal test_root_config, method_root.config.to_hash
  end
  
  #
  # assert_files
  #
  
  def setup_file(dir, path, content)
    path = method_root.path(dir, path)
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
        method_root.prepare(:output, File.basename(input_file)) do |file|
          file << "processed "
          file << File.read(input_file)
        end
      end
    end
  end
  
  def test_assert_files_fails_for_missing_expected_file
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file one"
    
    assert_raises(ASSERTION_ERROR) do
      assert_files do |input_files|
        input_files.collect do |input_file|
          method_root.prepare(:output, File.basename(input_file)) do |file|
            file << "processed "
            file << File.read(input_file)
          end
        end
      end
    end
  end
  
  def test_assert_files_fails_for_missing_output_file
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file one"
    setup_file :expected, "two.txt", "processed file two"
     
    assert_raises(ASSERTION_ERROR) do
      assert_files do |input_files|
        input_files.collect do |input_file|
          method_root.prepare(:output, File.basename(input_file)) do |file|
            file << "processed "
            file << File.read(input_file)
          end
        end.first
      end
    end
  end
  
  def test_assert_files_fails_for_different_content
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
    setup_file :expected, "one.txt", "processed file FLUNK"
    setup_file :expected, "two.txt", "processed file two"
    
    assert_raises(ASSERTION_ERROR) do
      assert_files do |input_files|
        input_files.collect do |input_file|
          method_root.prepare(:output, File.basename(input_file)) do |file|
            file << "processed "
            file << File.read(input_file)
          end
        end
      end
    end
  end
  
  def test_assert_files_fails_for_no_expected_files
    setup_file :input, "one.txt", "file one"
    setup_file :input, "two.txt", "file two"
   
    was_in_block = false
    assert_raises(ASSERTION_ERROR) do
      assert_files do |input_files| 
        was_in_block = true
        []
      end
    end

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
        method_root.prepare(:output, File.basename(input_file)) do |file|
          file << "processed "
          file << File.read(input_file)
        end
      end
    end
  end
end

class FileTestTestWithOptions < Test::Unit::TestCase
  extend Tap::Test
  
  acts_as_file_test(
    :root => "some/root/dir", 
    :relative_paths => {
      :input => 'input', 
      :output => 'output', 
      :expected => 'expected'},
    :absolute_paths => {:path => File.expand_path('/to/file')})
  
  def test_test_setup
    assert_equal File.expand_path("some/root/dir"), ctr[:root]
    assert_equal({
        :input => 'input', 
        :output => 'output', 
        :expected => 'expected'}, ctr.relative_paths)
    assert_equal({:path => File.expand_path('/to/file')}, ctr.absolute_paths)
  end
end
