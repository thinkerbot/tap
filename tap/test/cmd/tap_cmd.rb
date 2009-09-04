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
  
  #
  # help test
  #
  
  def test_tap_prints_help
    sh_match "% tap", 
    /usage: tap/, 
    /version #{Tap::VERSION}/
    
    sh_match "% tap --help", 
    /usage: tap/, 
    /version #{Tap::VERSION}/
  end
  
  #
  # command test
  #
  
  def test_tap_notifies_unknown_command
    sh_test %Q{
% tap unknown
Unknown command: 'unknown'
Type 'tap --help' for usage information.
}
  end
  
  def test_tap_loads_command
    method_root.prepare(:cmd, 'cmd.rb') do |io|
      io << "puts 'goodnight moon'"
    end
    
    sh_test %Q{
% tap cmd
goodnight moon
}
  end
  
  def test_commands_may_specify_env
    method_root.prepare(:cmd, 'run.rb') do |io|
      io << "puts 'alternative run'"
    end
    
    assert File.basename(Dir.pwd) != 'tap'
    
    sh_test %Q{
% tap tap:run -- dump 'standard run'
standard run
}

    sh_test %Q{
% tap #{File.basename(Dir.pwd)}:run -- dump 'standard run'
alternative run
}
  end
end