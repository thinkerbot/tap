require  File.dirname(__FILE__) + '/../tap_test_helper'
require 'tap/test/script_tester'

class ScriptTesterTest < Test::Unit::TestCase
  include Tap::Test
  
  attr_reader :cmd
  
  def setup
    @cmd = ScriptTester.new
  end
  
  #
  # initialize test
  #

  def test_initialize
    cmd = ScriptTester.new
    assert_equal nil, cmd.command_path
    assert_equal [], cmd.commands
    
    cmd = ScriptTester.new("path")
    assert_equal "path", cmd.command_path
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_command_path
    assert_equal "path", ScriptTester.new("path").to_s
  end
  
  #
  # split test
  #
  
  def test_split_documentation
    cmd = ScriptTester.new

    expected = [
     ["command one", "expected text for command one\n"],
     ["command two", nil],
     ["command three", "expected text for command three\n"]]
     
    assert_equal expected, cmd.split(%Q{
% command one
expected text for command one
% command two
% command three
expected text for command three
})
  end
  
  def test_split_splits_a_command_along_percent_signs_stripping_whitespace
    assert_equal [["command one", "text"]], cmd.split("   command one  \t\r\ntext")
    
    str = %Q{command one
text
% command two   \t
  ... text with % signs ...
  and whitespace
  
% command three
text}

    assert_equal [
      ["command one", "text\n"], 
      ["command two", "  ... text with % signs ...\n  and whitespace\n  \n"], 
      ["command three", "text"]
    ], cmd.split(str)
  end
  
  def test_split_uses_nil_for_expected_value_when_expected_is_empty
    str = %Q{command one
 
% command two   \t

\t \s 

}

    assert_equal [
      ["command one", nil], 
      ["command two", nil]
    ], cmd.split(str)
  end
  
  def test_split_ignores_empty_split_lines
    str = %Q{

% command one
%
%       \t \s \r
% command two}

    assert_equal [
      ["command one", nil], 
      ["command two", nil]
    ], cmd.split(str)
  end
  
end