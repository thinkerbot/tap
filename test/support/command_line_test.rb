require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/command_line'

class CommandLineTest < Test::Unit::TestCase
  include Tap::Support::CommandLine
  
  #
  # split test
  #
  
  def test_split
    argv = ["a", "-b", "--c", "--", "d", "-e", "--f"]
    assert_equal([
      [["a", "-b", "--c"], ["d", "-e", "--f"]]
    ], split(argv))
    
    argv.unshift("--")
    argv.push("--")
    assert_equal([
      [["a", "-b", "--c"], ["d", "-e", "--f"]]
    ], split(argv))
    
    argv.concat ["--++", "x", "-y", "--z"]
    assert_equal([
      [["a", "-b", "--c"], ["d", "-e", "--f"]], 
      [["x", "-y", "--z"]]
    ], split(argv))
    
    argv.concat ["--+", "m", "-n", "--o"]
    assert_equal([
      [["a", "-b", "--c"], ["d", "-e", "--f"]], 
      [["m", "-n", "--o"]], 
      [["x", "-y", "--z"]]
    ], split(argv))
  end
  
  #
  # parse_yaml tests
  #
  
  def test_parse_yaml_documentation
    str = {'key' => 'value'}.to_yaml
    assert_equal "--- \nkey: value\n", str
    assert_equal({'key' => 'value'}, parse_yaml(str))
    assert_equal "str", parse_yaml("str")
  end
  
  def test_parse_yaml_loads_arg_if_arg_matches_yaml_document_string
    string = "---\nkey: value"
    assert_equal({"key" => "value"}, parse_yaml(string))
  end
  
  def test_parse_yaml_returns_arg_unless_matches_yaml_document_string
    string = "key: value"
    assert_equal("key: value", parse_yaml(string))
  end
  
end