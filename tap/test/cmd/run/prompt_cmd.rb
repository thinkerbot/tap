require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test'

class PromptCmd < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  def prompt_test(script)
    inputs = []
    expected = ["starting prompt (enter for help):\n"]
    script.lstrip.split(/^--\//).each do |lines|
      next if lines.empty?
      
      lines = lines.split(/^/)
      inputs  << lines.shift
      expected.concat(lines)
    end
    
    actual = IO.popen(sh_test_options[:cmd] + " run -P", "r+") do |io|
      io.write inputs.join
      io.close_write
      io.read
    end
    assert_equal expected.join, actual
  end
  
  def test_basic_prompt
    prompt_test %q{
--//info
=> state: 1 (RUN) queue: 0
--//stop
}
  end
end