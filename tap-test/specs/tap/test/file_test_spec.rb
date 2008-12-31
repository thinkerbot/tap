require File.join(File.dirname(__FILE__), '../../tap_spec_helper')

describe "FileTest under RSpec" do
  acts_as_file_test  

  it "should return the underscored description1" do
    method_name.must_equal "should_return_the_underscored_description1"
  end
  
  it "should return the underscored description2" do
    method_name.must_equal "should_return_the_underscored_description2"
  end

  #
  # assert_files spec
  #
  
  it "should compare transformed inputs to expected" do
    assert_files do |input_files|
      input_files.collect do |input_file|
        target = method_root.prepare(:output, File.basename(input_file)) do |file|
          file << "processed "
          file << File.read(input_file)
        end
        target
      end
    end
  end
  
  it "should fail for missing expected file" do
    assert_raises(MiniTest::Assertion) do
      assert_files do |input_files|
        input_files.collect do |input_file|
          target = method_root.prepare(:output, File.basename(input_file)) do |file|
            file << "processed "
            file << File.read(input_file)
          end
          target
        end
      end
    end
  end
  
  it "should fail for missing output file" do
    assert_raises(MiniTest::Assertion) do
      assert_files do |input_files|
        input_files.collect do |input_file|
          target = method_root.prepare(:output, File.basename(input_file)) do |file|
            file << "processed "
            file << File.read(input_file)
          end
          target
        end.first
      end
    end
  end
  
  it "should fail for different content" do
    assert_raises(MiniTest::Assertion) do
      assert_files do |input_files|
        input_files.collect do |input_file|
          target = method_root.prepare(:output, File.basename(input_file)) do |file|
            file << "processed "
            file << File.read(input_file)
          end
          target
        end
      end
    end
  end
  
  it "should fail for no expected files" do
    was_in_block = false
    assert_raises(MiniTest::Assertion) do
      assert_files do |input_files| 
        was_in_block = true
        []
      end
    end
    
    was_in_block.must_equal false
  end
  
  it "should allow no expected files when specified" do
    was_in_block = false
    assert_files :expected_files => [] do |input_files| 
      assert_equal 2, input_files.length
      was_in_block = true
      []
    end
  
    was_in_block.must_equal true
  end
  
  it "should translate reference files when specified" do
    assert_files :reference_dir => method_root[:ref] do |input_files|
      input_files.collect do |input_file|
        target = method_root.prepare(:output, File.basename(input_file)) do |file|
          file << "processed "
          file << File.read(input_file)
        end
        target
      end
    end
  end

end