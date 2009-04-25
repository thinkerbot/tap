require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test/shell_test'

class ShellTestSample < Test::Unit::TestCase
  include Tap::Test::ShellTest

  CMD_PATTERN = '% inspect_argv'
  CMD = 'ruby -e "puts ARGV.inspect"'

  def test_echo
    assert_equal "goodnight moon", sh("echo goodnight moon").strip
  end

  def test_inspect_argv
    sh_test("% inspect_argv a b c") do |output|
      assert_equal %Q{["a", "b", "c"]\n}, output
    end

    sh_test %q{
% inspect_argv a b c
["a", "b", "c"]
}
  end
end

class ShellTestTest < Test::Unit::TestCase
  include Tap::Test::ShellTest
  
  #
  # sh_test test
  #
  
  def test_sh_test_documentation
    opts = {
      :cmd_pattern => '% argv_inspect',
      :cmd => 'ruby -e "puts ARGV.inspect"'
    }
  
    sh_test %Q{
% argv_inspect goodnight moon
["goodnight", "moon"]
}, opts
  
    sh_test %Q{
% argv_inspect hello world
["hello", "world"]
}, opts
  end
  
  #
  # sh_test_options test
  #
  
  class ShellTestOptionsExample
    include Tap::Test::ShellTest

    CMD_PATTERN = '% sample'
    CMD = 'command'
  end
  
  def test_sh_test_options_documentation
    expected = {
     :cmd_pattern => '% sample',
     :cmd => 'command'
    }
    assert_equal expected, ShellTestOptionsExample.new.sh_test_options
  end
end