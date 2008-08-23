require 'tap/spec'

describe Tap::Spec do
  extend Tap::Spec
  acts_as_file_spec :root => "some/root/dir"
  
  describe "trs" do 
    it "should have the acts_as_file_spec root directory" do
      check trs[:root].should == File.expand_path("some/root/dir")
    end
    
    it "should have the default :input, :output, :expected directories" do
      check trs.directories.should == {:input => 'input', :output => 'output', :expected => 'expected'}
    end
  end
end
