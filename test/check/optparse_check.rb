# checks on the behavior of optparse

require 'test/unit'
require 'optparse'

class OptparseCheck < Test::Unit::TestCase

  def test_option_parser_with_multiple_args_to_the_same_option
    values = []
    parser = OptionParser.new do |opts|
      opts.on("--value [VALUE]") do |value|
        values << value
      end
    end
    
    parser.parse ["--value", "a", 1, "--value", "b", "--value", "c"]
    assert_equal ["a", "b", "c"], values
  end
  
  def test_option_parser_with_smoosh_option
    values = []
    parser = OptionParser.new do |opts|
      opts.def_option("-eCONFIG:VALUE") do |value|
        values <<(value.split(':', 2))
      end
      
      opts.def_option("--env [CONFIG:VALUE]") do |value|
        values <<(value.split(':', 2))
      end
    end
    
    parser.parse ["-ea:1", "-e", "b:2", "--env", "ccc:three", "'-eval'"]
    assert_equal [["a", "1"], ["b", "2"], ["ccc", "three"]], values
  end
  
  def test_option_parser_allows_and_overlooks_non_string_arguments
    values = []
    opts = OptionParser.new do |opts|
      opts.on("--opt OPTION", "option") do |value|
        values << value
      end
    end
    
    argv = ["one", :two, [3], "--opt", "value", {:four => 4}]
    opts.parse!(argv)
    
    assert_equal ["one", :two, [3], {:four => 4}], argv
    assert_equal ["value"], values
  end
  
  def test_option_parser_does_not_allow_non_string_values
    values = []
    opts = OptionParser.new do |opts|
      opts.on("--opt OPTION", "option") do |value|
        values << value
      end
    end
    
    assert_raise(TypeError) { opts.parse!(["one", "--opt", :two]) }
    assert_raise(TypeError) { opts.parse!(["one", "--opt", 2]) }
    
    assert_equal [], values
  end
end