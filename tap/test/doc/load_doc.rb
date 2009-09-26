require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'
require 'tap/test'

class LoadDoc < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test :cleanup_dirs => [:sample]
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  def test_load_string
    sh_test %q{
% tap run -- load string --: dump
string
}
  end

  def test_load_pipe
    cmd = "echo goodnight moon | #{sh_test_options[:cmd]} run -- load --: dump"
    assert_equal "goodnight moon", sh(cmd).strip
  end

  def test_load_redirect
    method_root.prepare(:sample, 'somefile.txt') {|io| io << "contents of somefile"}
    method_root.chdir(:sample) do
      sh_test %q{
% tap run -- load --: dump < somefile.txt
contents of somefile
}
    end
  end
end