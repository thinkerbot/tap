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
        check trs.directories.should == {
          :input => 'input', 
          :output => 'output', 
          :expected => 'expected'}

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
end