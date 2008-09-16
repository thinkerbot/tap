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
  
end