require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class GenerateCmdTest < Test::Unit::TestCase
  tap_root = File.expand_path(File.dirname(__FILE__) + "/../..")
  load_paths = [
    "-I'#{tap_root}/../configurable/lib'",
    "-I'#{tap_root}/../lazydoc/lib'",
    "-I'#{tap_root}/../tap/lib'",
    "-I'#{tap_root}/../tap-tasks/lib'"
  ]
  
  acts_as_shell_test(
    :cmd_pattern => '% tap',
    :cmd => (["ruby"] + load_paths + ["'#{tap_root}/../tap/bin/tap'"]).join(" "), 
    :env => {'TAP_GEMS' => ''}
  )

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