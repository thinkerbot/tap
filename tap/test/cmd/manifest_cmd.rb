require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test'

class ManifestCmd < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test :cleanup_dirs => [:root]
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
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
  # help
  #
  
  def test_manifest_prints_listing_of_resources
    sh_match "% tap manifest", 
    /tap:\s+\(#{TAP_ROOT}\)/,
    /^\s+join$/,
    /join\s+\(.*tap\/join.rb\)/,
    /^\s+middleware$/,
    /debugger\s+\(.*tap\/middlewares\/debugger.rb\)/,
    /^\s+task$/,
    /dump\s+\(.*tap\/tasks\/dump.rb\)/
  end
end