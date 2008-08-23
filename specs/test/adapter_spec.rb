require 'tap/spec/adapter'
require 'ostruct'

describe Tap::Spec::Adapter do
  include Tap::Spec::Adapter
  
  describe('check') do
    it "should consume should statements without warnings or errors" do
      check 1.should == 1
      check 2.should == 2
      
      check 1.should_not == 2
      check 2.should_not == 1
      
      check 'str'.should =~ /t/
      check 'str'.should_not =~ /n/
    end
  end
end