require 'tap/spec'

describe "Tap::Spec" do
  acts_as_file_test :root => "some/root/dir"
  
  describe "ctr" do 
    it "should have the acts_as_file_spec root directory" do
      ctr[:root].should == File.expand_path("some/root/dir")
    end
    
    it "should have the default :input, :output, :expected directories" do
      ctr.directories.should == {:input => 'input', :output => 'output', :expected => 'expected'}
    end
  end
end
