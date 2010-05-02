require File.expand_path('../../../../test_helper.rb', __FILE__) 
require 'tap/tasks/dump/yaml'
require 'stringio'

class DumpYamlTest < Test::Unit::TestCase
  include Tap::Tasks
  acts_as_tap_test
  acts_as_shell_test(SH_TEST_OPTIONS)

  #
  # documentation test
  #

  def test_documentation
    sh_test %q{
% tap load/yaml "{key: value}" -: dump/yaml
--- 
key: value
}
  end
  
  #
  # dump test
  #
  
  def test_dump_dumps_object_to_io_as_yaml
    io = StringIO.new
    Dump::Yaml.new.dump({'key' => 'value'}, io)
    assert_equal "--- \nkey: value\n", io.string
  end
end