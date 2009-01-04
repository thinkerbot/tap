require File.join(File.dirname(__FILE__), '../tap_test_helper') 
require 'tap/rake'

class Tap::RakeTest < Test::Unit::TestCase
  acts_as_tap_test 
  
  def test_rake
    t = Tap::Rake.new :key => 'value'
    
    # specify the application config
    with_config(:quiet => true, :debug => true) do  
      
      # run the task with some inputs
      t.enq("one")
      app.run
      
      # check the configuration and outputs
      assert_equal({:key  => 'value'}, t.config)
      assert_audit_equal [[nil, "one"], [t, "one was processed with value"]], app._results(t).first

    end
  end
end