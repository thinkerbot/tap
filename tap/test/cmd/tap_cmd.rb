require File.join(File.dirname(__FILE__), '../doc_test_helper')
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class CmdDoc < Test::Unit::TestCase 
  include Doctest
  include MethodRoot
  
  def setup
    super
    @pwd = Dir.pwd
    method_root.chdir(:root, true)
  end
  
  def teardown
    Dir.chdir(@pwd)
    super
  end
  
  def test_tap_prints_help
    sh_match "% tap", 
    /usage: tap/, 
    /version #{Tap::VERSION}/
    
    sh_match "% tap --help", 
    /usage: tap/, 
    /version #{Tap::VERSION}/
  end
  
  def test_tap_handles_unknown_command
    sh_test %Q{
% tap unknown
Unknown command: 'unknown'
Type 'tap --help' for usage information.
}
  end
end