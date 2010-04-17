require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb') 
require 'tap/tasks/insert'

class InsertTest < Test::Unit::TestCase
  acts_as_tap_test 
  acts_as_shell_test(SH_TEST_OPTIONS)
  
  #
  # documentation test
  #

  def test_documentation
    sh_test %q{
      % tap load moon -: insert goodnight %0 -: inspect
      ["goodnight", "moon"]
    }, :env => {'TAP_PATH' => '../tap:.'}
    
    sh_test %q{
      % tap insert goodnight %0 -: inspect -/enq 0 moon
      ["goodnight", "moon"]
    }
    
    sh_test %q{
      % tap load a -: insert %0 %0 %1 -: inspect
      ["a", "a", nil]
    }, :env => {'TAP_PATH' => '../tap:.'}
  end
end