require  File.join(File.dirname(__FILE__), '/../tap_test_helper')
require 'tap/test/script_methods'

class WebsiteTest < Test::Unit::TestCase
  acts_as_script_test :directories => {}
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
    
  def test_documentation
    script_test(method_root) do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
      cmd.check " run -- hello Cecily", "Prints help" 
      cmd.check " run -- hello James Cecily --iterate --greeting=hola", "Prints help" 
      cmd.check " run -- hello --help", "Prints help" 
    end
  end
  
end