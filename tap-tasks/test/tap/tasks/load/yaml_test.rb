require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/tasks/load/yaml'
require 'stringio'

class LoadYamlTest < Test::Unit::TestCase
  include Tap::Tasks
  acts_as_tap_test
  acts_as_shell_test(:cmd => TAP_CMD_PATH, :cmd_pattern => '% tap')
  
  #
  # documentation test
  #
  
  def test_documentation
    sh_test %q{
% tap run -- load/yaml "{key: value}" --: dump/yaml
--- 
key: value
}
  end
  
  #
  # load test
  #
  
  def test_load_loads_io_as_YAML
    io = StringIO.new "--- \nkey: value\n"
    assert_equal({'key' => 'value'}, Load::Yaml.new.load(io))
  end
end