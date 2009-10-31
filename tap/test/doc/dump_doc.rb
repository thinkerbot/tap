require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'
require 'tap/test'

class DumpDoc < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test :cleanup_dirs => [:sample]
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    "TAP_GEMS=",
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  def test_dump_string
    method_root.chdir(:sample, true) do
      assert_equal "", sh("#{sh_test_options[:cmd]} run -- dump content --output filepath.txt")
      assert_equal "content\n", File.read("filepath.txt")
    end
  end

  def test_dump_iterate
      sh_test %q{
% tap run -- load hello -- load world -- dump --[0,1][2]i.sync
hello
world
}
  end
  
  def test_dump_pipe
    # for some reason this adds an extra \n on windows?
    result = sh %Q{#{sh_test_options[:cmd]} run -- load hello --: dump | more}
    assert result =~ /\Ahello\n+\z/
  end
  
  def test_dump_redirect
    method_root.chdir(:sample, true) do
      assert_equal "", sh("#{sh_test_options[:cmd]} run -- load hello --: dump 1> results.txt")
      assert_equal "hello\n", sh("more results.txt")
    end
  end
end