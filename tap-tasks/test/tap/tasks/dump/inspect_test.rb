require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/tasks/dump/inspect'
require 'stringio'

class DumpInspectTest < Test::Unit::TestCase
  include Tap::Tasks
  acts_as_shell_test(SH_TEST_OPTIONS)

  #
  # documentation test
  #

  def test_documentation
    sh_test %q{
% tap run -- load/yaml "{key: value}" --: inspect
{"key"=>"value"}
}

    sh_test %q{
% tap run -- load string --: inspect -m length
6
}
  end
end