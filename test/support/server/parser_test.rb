require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/server/parser'

class Tap::Support::Server::ParserTest < Test::Unit::TestCase
  include Tap::Support::Server

  # rounds syntax
  # 0[input]=dump&0[config]=str&1[input]=dump&1[config]=str
  # sequence[1]=1,2,3
  # fork[1]=2,3
  # round[0]=1,2,3
  # ....
  
  # 
  # Parser.parse_argv test
  #
  
  def test_parse_argv_parses_task_from_hash_task
    assert_equal(["Task"], Parser.parse_argv('task' => 'Task'))
  end
  
  def test_parse_argv_raises_error_if_no_task_is_specified
    assert_raise(ArgumentError) { Parser.parse_argv() }
    assert_raise(ArgumentError) { Parser.parse_argv('config' => {}) }
  end
  
  def test_parse_argv_constructs_config_options_from_hash_config
    argh = {
      'task' => 'Task',
      'config' => {'key' => 'value'}}
    assert_equal(['Task', '--key', 'value'], Parser.parse_argv(argh))
  end
  
  def test_parse_argv_loads_configs_as_yaml_if_configs_are_a_string
    argh = {
      'task' => 'Task',
      'config' => {'key' => 'value'}.to_yaml}
    assert_equal(['Task', '--key', 'value'], Parser.parse_argv(argh))
  end
  
  def test_parse_argv_raises_error_if_config_is_not_a_hash_string_or_nil
    assert_raise(ArgumentError) { Parser.parse_argv('config' => 1) }
    assert_raise(ArgumentError) { Parser.parse_argv('config' => []) }
  end
  
  def test_parse_argv_concats_inputs_in_inputs
    argh = {
      'task' => 'Task',
      'inputs' => [1,2,3]}
    assert_equal(['Task', 1,2,3], Parser.parse_argv(argh))
  end
  
  def test_parse_argv_loads_inputs_as_yaml_if_inputs_are_a_string
    argh = {
      'task' => 'Task',
      'inputs' => [1,2,3].to_yaml}
    assert_equal(['Task', 1,2,3], Parser.parse_argv(argh))
  end
  
  def test_parse_argv_raises_error_if_inputs_is_not_an_array_string_or_nil
    assert_raise(ArgumentError) { Parser.parse_argv('inputs' => 1) }
    assert_raise(ArgumentError) { Parser.parse_argv('inputs' => {}) }
  end
  
  #
  # Parser.parse_sequence test
  #
  
  def test_parse_sequence_splits_each_input_by_comma_and_collects_integers
    assert_equal [[1,2,3], [4,5]], Parser.parse_sequence(['1,2,3', '4,5'])
  end
  
  def test_parse_sequence_works_on_single_argument
    assert_equal [[1,2,3]], Parser.parse_sequence('1,2,3')
  end
  
  #
  # Parser.parse_pairs test
  #
  
  def test_parse_pairs_splits_each_input_by_comma_and_collects_integers_while_shifting_off_first_value
    assert_equal [[1,[2,3]], [4,[5]]], Parser.parse_pairs(['1,2,3', '4,5'])
  end
  
  def test_parse_parse_pairs_works_on_single_argument
    assert_equal [[1,[2,3]]], Parser.parse_pairs('1,2,3')
  end
  
  #
  # INDEX regexp test
  #
  
  def test_INDEX_regexp
    r = Parser::INDEX
    assert r =~ "1"
    assert r =~ "123"
    
    assert r !~ ""
    assert r !~ "string"
    assert r !~ " 123 "
  end

  #
  # parse test
  #
  
  def test_parse_pulls_out_argvs_for_each_task
    argh = {
      "0" => {'task' => 'zero', 'config' => {'opt' => 'value'}, 'inputs' => ['1', '2', '3']},
      "1" => {'task' => 'one', 'config' => {'opt' => 'alt'}, 'inputs' => ['4']}
    }
    
    assert_equal [
      ['zero', '--opt', 'value', '1', '2', '3'],
      ['one', '--opt', 'alt', '4']
    ], Parser.new(argh).argvs
  end
  
  def test_parse_pulls_out_workflow_declarations
    argh = {
      "sequence" => ["1,2,3", "4,5"],
      "round" => ["0,0,1", "1,3"],
      "merge" => "0,1,2",
      "sync_merge" => ""
    }
    
    parser = Parser.new(argh)
    assert_equal [[1,2,3],[4,5]], parser.sequences
    assert_equal [[0,[0,1]],[1,[3]]], parser.rounds
    assert_equal [[0,[1,2]]], parser.merges
    assert_equal [], parser.sync_merges
    assert_equal [], parser.forks
  end
  
end