require 'tap/spec/file_methods'

describe Tap::Spec::FileMethods do
  include Tap::Spec::FileMethods
  
  self.trs = Tap::Root.new(
    __FILE__.chomp("_spec.rb"), 
    {:input => 'input', :output => 'output', :expected => 'expected'})
    
  describe('method_name') do
    it "should return the underscored description1" do
      method_name.should == "should_return_the_underscored_description1"
    end
    
    it "should return the underscored description2" do
      method_name.should == "should_return_the_underscored_description2"
    end
  end

  describe('make_test_directories') do
    it "should make trs directories" do
      begin
        root = File.expand_path(__FILE__.chomp("_spec.rb"))
        
        check root.should == trs[:root]
        check trs.directories.should == {:input => 'input', :output => 'output', :expected => 'expected'}

        trs.directories.values.each do |dir|
          dir_path = File.join(root, "should_make_trs_directories", dir.to_s)
          File.exists?(dir_path).should be_false
        end

        make_test_directories

        trs.directories.values.each do |dir|
          dir_path = File.join(root, "should_make_trs_directories", dir.to_s)
          File.exists?(dir_path).should be_true
        end
      ensure
        dir =  File.join(File.join(root, "should_make_trs_directories"))
        FileUtils.rm_r dir if File.exists?(dir)
      end
    end
  end
  
  describe('assert_files') do
    it "should compare transformed inputs to expected" do
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
    
    it "should fail for missing expected file" do
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
      
      failed.should be_true
    end
    
    it "should fail for missing output file" do
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
      
      failed.should be_true
    end
    
    it "should fail for different content" do
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
      
      failed.should be_true
    end
    
    it "should fail for no expected files" do
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
      
      failed.should be_true
      was_in_block.should be_false
    end
    
    it "should allow no expected files when specified" do
      was_in_block = false
      assert_files :expected_files => [] do |input_files| 
        assert_equal 2, input_files.length
        was_in_block = true
        []
      end
    
      was_in_block.should be_true
    end
    
    it "should translate reference files when specified" do
      assert_files :reference_dir => method_dir(:ref) do |input_files|
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
  end
end