require File.join(File.dirname(__FILE__), '../../tap_test_helper')

# documentation test
class FileTestDocTest < Test::Unit::TestCase
  extend Tap::Test
  
  acts_as_file_test

  def test_something
    # each test class has a class test root (ctr)
    # and each test method has a method-specific
    # root (method_root)

    assert_equal File.expand_path(__FILE__.chomp('_test.rb')), ctr.root
    assert_equal File.join(ctr.root, "/test_something"), method_root.root
    assert_equal File.join(ctr.root, "/test_something/input"), method_root[:input]
    
    # files in the :output and :tmp directories are cleared
    # before and after each test; this passes each time the
    # test is run with no additional cleanup:

    assert !File.exists?(method_root[:tmp])

    tmp_file = method_root.prepare(:tmp, 'sample.txt') {|file| file << "content" }
    assert_equal "content", File.read(tmp_file)

    # the assert_files method compares files produced
    # by the block the expected files, ensuring they
    # are the same (see the documentation for the 
    # simplest use of assert_files)
    
    expected_file = method_root.prepare(:expected, 'output.txt') {|file| file << 'expected output' }

    # passes
    assert_files do 
      method_root.prepare(:output, 'output.txt') {|file| file << 'expected output' }
    end
  end
  
  def test_sub
    assert_files do |input_files|
      input_files.collect do |filepath|
        input = File.read(filepath)
        method_root.prepare(:output, File.basename(filepath)) do |f|
          f << input.gsub(/input/, "output")
        end 
      end
    end
  end
end
