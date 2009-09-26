require File.join(File.dirname(__FILE__), '../../doc_test_helper')
require File.join(File.dirname(__FILE__), '../../tap_test_helper')

class PromptCmd < Test::Unit::TestCase 
  include Doctest
  
  def prompt_test(script)
    inputs = []
    expected = ["starting prompt (enter for help):\n"]
    script.lstrip.split(/^--\//).each do |lines|
      next if lines.empty?
      
      lines = lines.split(/^/)
      inputs  << lines.shift
      expected.concat(lines)
    end
    
    actual = IO.popen(CMD + " run -P", "r+") do |io|
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