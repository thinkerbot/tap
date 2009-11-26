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
  
  # note this crazy script for testing the prompt does not
  # work in the general case, and will likely stop working
  # if ever the prompt does completions and such.  See
  # http://gist.github.com/194470 for some experiments.
  def prompt_test(script)
    inputs = []
    expected = ["starting prompt (help for help):\n"]
    script.lstrip.split(/^--\//).each do |lines|
      next if lines.empty?
      
      lines = lines.split(/^/)
      inputs  << lines.shift
      expected.concat(lines)
    end
    
    actual = IO.popen(sh_test_options[:cmd] + " run -- prompt", "r+") do |io|
      io.write inputs.join
      io.close_write
      io.read
    end
    assert_alike RegexpEscape.new(expected.join), actual
  end
  
  def test_basic_prompt
    prompt_test %q{
--/info
=> state: 1 (RUN) queue: 0
--/stop
}
  end

  def test_build_from_prompt
    prompt_test %q{
--/set 0 load
=> #<Tap::Tasks::Load:...:>
--/set 1 dump
=> #<Tap::Tasks::Dump:...:>
--/set 2 join 0 1
=> #<Tap::Join:...:>
--/0/enq 'goodnight moon'
=> #<Tap::Tasks::Load:...:>
--/run
goodnight moon
}
  end
end