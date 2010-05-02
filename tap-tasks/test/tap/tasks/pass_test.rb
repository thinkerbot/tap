require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb') 
require 'tap/tasks/pass'

class PassTest < Test::Unit::TestCase
  acts_as_tap_test 
  acts_as_shell_test(SH_TEST_OPTIONS)

  attr_reader :task
  
  def setup
    @task = Tap::Tasks::Null.new
    super
  end
  
  #
  # documentation test
  #

  def test_pass_documentation
    tapfile = method_root.prepare('tapfile') do |io|
      io << %q{
        task :reverse do |config, str|
          str.reverse
        end
      }
    end
    
    sh_test %q{
% tap load/yaml '[abc, xyz]' -:i pass -: reverse - inspect - sync 1,2 3
["abc", "cba"]
["xyz", "zyx"]
}, :env => SH_TEST_OPTIONS[:env].merge('TAPFILE' => tapfile)
  end
end