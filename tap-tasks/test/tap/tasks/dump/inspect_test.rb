require File.expand_path('../../../../test_helper.rb', __FILE__) 
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
% tap load/yaml "{key: value}" -: inspect
{"key"=>"value"}
}
  end
end