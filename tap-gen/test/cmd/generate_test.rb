require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class GenerateTest < Test::Unit::TestCase 
  acts_as_shell_test(:cmd => TAP_CMD_PATH, :cmd_pattern => '% tap')

  #
  # help test
  #

  def test_generate_prints_help
    sh_test "% tap generate --help" do |result|
      assert result =~ /usage: tap generate/
    end
  end

end