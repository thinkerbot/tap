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
      assert result =~ /generators:/
      assert result =~ /root\s+# /
    end
  end
  
  def test_generate_prints_help_for_no_generator_specified
    sh_test "% tap generate" do |result|
      assert result =~ /usage: tap generate/
      assert result =~ /generators:/
      assert result =~ /root\s+# /
    end
  end
  
end