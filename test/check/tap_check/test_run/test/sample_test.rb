require File.join(File.dirname(__FILE__), 'tap_test_helper.rb') 
require 'sample'

class SampleTest < Test::Unit::TestCase
  acts_as_tap_test 
  
  def test_sample
    t = Sample.new nil, :key => 'value'
    
    # specify application options
    with_options(:quiet => true, :debug => true) do	
      
      # run the task with some inputs
      t.enq("one")
      app.run
			
      # check the configuration and outputs
      assert_equal({:key  => 'value'}, t.config)
      assert_audit_equal ExpAudit[[nil, "one"], [t, "one was processed with value"]], app._results(t).first

    end
  end
  
end