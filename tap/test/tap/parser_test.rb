require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/parser'

class ParserTest < Test::Unit::TestCase
  Parser = Tap::Parser
  
  attr_accessor :parser
  
  def setup
    super
    @parser = Parser.new  
  end
  
  #
  # BREAK test
  #
  
  def test_BREAK_regexp
    r = Parser::BREAK
    
    # standard breaks
    assert '-' =~ r
    assert '--' =~ r
    assert '-:' =~ r
    assert '-!' =~ r
    assert '-/' =~ r
    assert '--/' =~ r
    
    # unused breaks
    assert '-@' =~ r
    assert '-*' =~ r
    
    # escapes
    assert '---' =~ r
    assert '-.' =~ r
    assert '.-' !~ r
    
    # non-matching
    assert 'goodnight' !~ r
    assert 'moon' !~ r
    assert '8' !~ r
    
    assert '-o' !~ r
    assert '-opt' !~ r
    assert '--opt' !~ r
    assert '--no-opt' !~ r
  end
  
  #
  # OPTION test
  #
  
  def test_OPTION_regexp
    r = Parser::OPTION
    
    # options
    assert '-o' =~ r
    assert '-opt' =~ r
    assert '--opt' =~ r
    assert '--no-opt' =~ r
    
    # non-matching
    assert '-' !~ r
    assert '--' !~ r
    assert '-:' !~ r
    assert '-!' !~ r
    assert '-/' !~ r
    assert '--/' !~ r
    assert '---' !~ r
    
    assert 'goodnight' !~ r
    assert 'moon' !~ r
    assert '8' !~ r
  end

  #
  # JOIN test
  #
  
  def test_JOIN_regexp
    r = Parser::JOIN
    
    assert '-:' =~ r
    assert_equal nil, $1
  
    assert '-:i' =~ r
    assert_equal 'i', $1
    
    assert '-:is.join' =~ r
    assert_equal 'is.join', $1
  end
  
  #
  # MODIFIER test
  #
  
  def test_MODIFIER_regexp
    r = Parser::MODIFIER
    
    assert 'i' =~ r
    assert_equal 'i', $1
    assert_equal nil, $2
    
    assert 'is' =~ r
    assert_equal 'is', $1
    assert_equal nil, $2
    
    assert 'is.sync' =~ r
    assert_equal 'is', $1
    assert_equal 'sync', $2
    
    assert '.sync' =~ r
    assert_equal '', $1
    assert_equal 'sync', $2
    
    assert 'A.sync' =~ r
    assert_equal 'A', $1
    assert_equal 'sync', $2
    
    assert 'is.' =~ r
    assert_equal 'is', $1
    assert_equal '', $2
    
    # non-matching cases
    assert ' join -i -s' !~ r
    assert ' ' !~ r
    assert '1' !~ r
  end
  
  #
  # SIGNAL test
  #
  
  def test_SIGNAL_regexp
    r = Parser::SIGNAL
    
    assert '-/obj/sig' =~ r
    assert_equal nil, $1
    assert_equal 'obj/sig', $2
    
    assert '-//sig' =~ r
    assert_equal nil, $1
    assert_equal '/sig', $2
    
    assert '-/sig' =~ r
    assert_equal nil, $1
    assert_equal 'sig', $2
    
    assert '-/' =~ r
    assert_equal nil, $1
    assert_equal '', $2
    
    # exec signals
    assert '--/obj/sig' =~ r
    assert_equal '-', $1
    assert_equal 'obj/sig', $2
    
    assert '--/sig' =~ r
    assert_equal '-', $1
    assert_equal 'sig', $2
    
    # non-matching
    assert 'str' !~ r
  end
  
  #
  # parse test
  #
  
  def test_parse_parses_set_breaks
    parser.parse %w{- a b c - x y z}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a', 'b', 'c']}, :set],
      [{'sig' => 'set', 'args' => ['1', 'x', 'y', 'z']}, :set]
    ], parser.specs
  end
  
  def test_parse_parses_enque_breaks
    parser.parse %w{-- a b c -- x y z}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a', 'b', 'c']}, :enq],
      [{'sig' => 'set', 'args' => ['1', 'x', 'y', 'z']}, :enq]
    ], parser.specs
  end
  
  def test_parse_parses_exec_breaks
    parser.parse %w{-! a b c -! x y z}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a', 'b', 'c']}, :exe],
      [{'sig' => 'set', 'args' => ['1', 'x', 'y', 'z']}, :exe]
    ], parser.specs
  end
  
  def test_parse_unshifts_enque_break_if_argv_does_not_start_with_a_break
    parser.parse %w{a b c}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a', 'b', 'c']}, :enq]
    ], parser.specs
  end
  
  def test_parse_allows_options_in_specs
    parser.parse %w{-- a -b --c}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a', '-b', '--c']}, :enq],
    ], parser.specs
  end
  
  def test_parse_adds_specs_for_empty_breaks
    parser.parse %w{-- a - -! -- b --}
    assert_equal [
      [{"args"=>["0", "a"], "sig"=>"set"}, :enq],
      [{"args"=>["1"], "sig"=>"set"}, :set],
      [{"args"=>["2"], "sig"=>"set"}, :exe],
      [{"args"=>["3", "b"], "sig"=>"set"}, :enq],
      [{"args"=>["4"], "sig"=>"set"}, :enq]
    ], parser.specs
  end
  
  def test_parse_is_non_destructive
    argv = %w{-- a b c}
    assert_equal [], parser.parse(argv)
    assert_equal %w{-- a b c}, argv
  end
  
  def test_parse_does_not_parse_escaped_args
    parser.parse %w{-- a -. -- --: -z- .- b -- c}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a', '--', '--:', '-z-', 'b']}, :enq],
      [{'sig' => 'set', 'args' => ['1', 'c']}, :enq]
    ], parser.specs
  end
  
  def test_parse_stops_at_end_flag
    parser.parse %w{-- a --- -- b}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a']}, :enq],
    ], parser.specs
  end
  
  def test_parse_returns_remaining_args
    assert_equal [], parser.parse(%w{-- a -- b})
    assert_equal ['b'], parser.parse(%w{-- a --- b})
  end
  
  def test_parse_resets_counter_and_appends_specs_for_each_call
    parser.parse %w{-- a}
    parser.parse %w{-- b}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a']}, :enq],
      [{'sig' => 'set', 'args' => ['0', 'b']}, :enq]
    ], parser.specs
  end
  
  def test_parse_raises_error_for_invalid_breaks
    err = assert_raises(RuntimeError) { parser.parse %w{--[]} }
    assert_equal 'invalid break: --[] (unknown)', err.message
    
    err = assert_raises(RuntimeError) { parser.parse %w{- -:!} }
    assert_equal 'invalid break: -:! (invalid join modifier)', err.message
  end
  
  #
  # parse! test
  #
  
  def test_parse_bang_is_destructive
    argv = %w{-- a b c}
    assert_equal [], parser.parse!(argv)
    assert_equal [], argv
  end
  
  #
  # join break test
  # 
  
  def test_parser_parses_join_to_join_preceding_and_following_specs
    parser.parse %w{-- a -: b}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a']}, :enq],
      [{'sig' => 'set', 'args' => ['1', 'b']}, :set],
      [{'sig' => 'set', 'args' => [nil, Tap::Join, '0', '1']}, :set]
    ], parser.specs
  end
  
  def test_joins_can_add_a_modifier_to_specify_short_flags_and_class
    parser.parse %w{-- a -:is.class b}
    assert_equal [
      [{'sig' => 'set', 'args' => ['0', 'a']}, :enq],
      [{'sig' => 'set', 'args' => ['1', 'b']}, :set],
      [{'sig' => 'set', 'args' => [nil, 'class', '-i', '-s', '0', '1']}, :set]
    ], parser.specs
  end
  
  def test_join_raises_error_for_no_preceding_spec
    err = assert_raises(RuntimeError) { parser.parse %w{-:!} }
    assert_equal 'invalid break: -:! (no prior entry)', err.message
  end
  
  #
  # signal tests
  #
  
  def test_parser_parses_signals
    parser.parse %w{-/var/sig a b}
    parser.parse %w{-/var/ a b}
    parser.parse %w{-//sig a b}
    parser.parse %w{-/sig a b}
    parser.parse %w{-// a b}
    parser.parse %w{-/ a b}
    parser.parse %w{--/var/sig a b}
    
    assert_equal [
      [{'sig' => 'set', 'args' => [nil, Tap::Tasks::Signal, 'var/sig', 'a', 'b']}, :enq],
      [{'sig' => 'set', 'args' => [nil, Tap::Tasks::Signal, 'var/',    'a', 'b']}, :enq],
      [{'sig' => 'set', 'args' => [nil, Tap::Tasks::Signal, '/sig',    'a', 'b']}, :enq],
      [{'sig' => 'set', 'args' => [nil, Tap::Tasks::Signal, 'sig',     'a', 'b']}, :enq],
      [{'sig' => 'set', 'args' => [nil, Tap::Tasks::Signal, '/',       'a', 'b']}, :enq],
      [{'sig' => 'set', 'args' => [nil, Tap::Tasks::Signal, '',        'a', 'b']}, :enq],
      [{'sig' => 'set', 'args' => [nil, Tap::Tasks::Signal, 'var/sig', 'a', 'b']}, :exe]
    ], parser.specs
  end
end