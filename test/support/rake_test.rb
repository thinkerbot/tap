require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class RakeTest < Test::Unit::TestCase
  acts_as_tap_test
  
  def test_tap_with_rake
    extended_test do
      require 'tap/support/rake'
      app.extend Tap::Support::Rake
      
      runlist = []
      t1 = task :task => [:prerequisite] do
        runlist << :task 
      end
      t2 = task :prerequisite do
        runlist << :prerequisite
      end
      
      assert_equal [], runlist
      app.task(:task).enq
      app.run
      assert_equal [:prerequisite, :task], runlist
    
      # notice the tasks do not get re-run
      app.task(:task).enq
      app.run
      assert_equal [:prerequisite, :task], runlist
      
      # check that Rake still works natively
      t1.instance_variable_set("@already_invoked", false)
      t2.instance_variable_set("@already_invoked", false)
      
      Rake.application.lookup(:task).invoke
      assert_equal [:prerequisite, :task, :prerequisite, :task], runlist
    end
  end
end
