require File.join(File.dirname(__FILE__), '../../app_test_helper')
require 'tap/app/join'

class JoinTest < Test::Unit::TestCase
  include JoinTestMethods
  Join = Tap::App::Join
  
  attr_accessor :join
  
  def setup
    super
    @join = Join.new
  end
  
  #
  # parse test
  #
  
  def test_parse_initializes_with_config_specified_by_modifier
    join = Join.parse([])
    assert_equal false, join.iterate
    
    join = Join.parse(["i"])
    assert_equal true, join.iterate
  end
  
  #
  # parse_modifier test
  #

  def test_parse_modifiers_documentation
    assert_equal({}, Join.parse_modifier(""))
    assert_equal({:iterate => true, :stack => true}, Join.parse_modifier("ik"))
  end

  def test_parse_modifier_raises_error_for_unknown_options
    assert_raises(RuntimeError) { Join.parse_modifier("q") }
  end
  
  #
  # join tests
  #
  
  def test_simple_join
    t0, t1, t2, t3 = single_tracers(0,1,2,3)

    join.join([t0,t1], [t2,t3])
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 2 3
      1 2 3
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], results[t2]
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t3, '0 3']], 
      [[nil, ''],[t1, '1'],[t3, '1 3']],
    ], results[t3]
  end
  
  def test_stack_join
    t0, t1, t2, t3 = single_tracers(0,1,2,3)
    
    join.stack = true
    join.join([t0,t1], [t2,t3])
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 1
      2 3
      2 3
    }, runlist
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t2, '0 2']], 
      [[nil, ''],[t1, '1'],[t2, '1 2']],
    ], results[t2]
    
    assert_equal [
      [[nil, ''],[t0, '0'],[t3, '0 3']], 
      [[nil, ''],[t1, '1'],[t3, '1 3']],
    ], results[t3]
  end
  
  def test_iterate_join
    t0, t1 = multi_tracers(0,1)
    t2, t3 = single_tracers(2,3)
    
    join.iterate = true
    join.join([t0,t1], [t2,t3])
    t0.enq ['a', 'b']
    t1.enq ['c', 'd']
    app.run
  
    assert_equal %w{
      0 2
        2
        3
        3
      1 2
        2
        3
        3
    }, runlist
  
    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t2, 'a 0 2']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t2, 'b 0 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[0, 'c 1'],[t2, 'c 1 2']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[1, 'd 1'],[t2, 'd 1 2']]
    ], results[t2]
    
    assert_equal [
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[0, 'a 0'],[t3, 'a 0 3']],
      [[nil,['a', 'b']],[t0,['a 0', 'b 0']],[1, 'b 0'],[t3, 'b 0 3']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[0, 'c 1'],[t3, 'c 1 3']],
      [[nil,['c', 'd']],[t1,['c 1', 'd 1']],[1, 'd 1'],[t3, 'd 1 3']]
    ], results[t3]
  end
  
  def test_splat_join
    t0, t1 = multi_tracers(0,1)
    t2, t3 = splat_tracers(2,3)
    
    join.splat = true
    join.join([t0,t1], [t2,t3])
    
    t0.enq(['a', 'b'])
    t1.enq(['a', 'b'])
    app.run
  
    assert_equal %w{
      0 2 3
      1 2 3
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    m1a = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [0, "a 1"]]
    m1b = [[nil, ["a", "b"]], [t1, ["a 1", "b 1"]], [1, "b 1"]]
    
    assert_equal [
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]],
      [[m1a, m1b], [t2, ['a 1 2', 'b 1 2']]]
    ], results[t2]
    
    assert_equal [
      [[m0a, m0b], [t3, ['a 0 3', 'b 0 3']]],
      [[m1a, m1b], [t3, ['a 1 3', 'b 1 3']]]
    ], results[t3]
  end
  
  def test_aggregate_join
    t0, t1 = single_tracers(0,1)
    t2, t3 = splat_tracers(2,3)
    
    join.aggregate = true
    join.join([t0,t1], [t2,t3])
    t0.enq ''
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 1
      2 3
    }, runlist
    
    m0 = [[nil, ''],[t0, '0']]
    m1 = [[nil, ''],[t1, '1']]
    
    assert_equal [
      [[m0, m1], [t2, ["0 2", "1 2"]]]
    ], results[t2]
    
    assert_equal [
      [[m0, m1], [t3, ["0 3", "1 3"]]]
    ], results[t3]
  end
  
  def test_aggregate_join_does_not_carry_over
    t0, t1 = single_tracers(0,1)
    t2, t3 = splat_tracers(2,3)
    
    join.aggregate = true
    join.join([t0,t1], [t2,t3])
    t0.enq ''
    app.run
    
    t1.enq ''
    app.run
  
    assert_equal %w{
      0 
      2 3
      1
      2 3
    }, runlist
    
    assert_equal [
      [[nil, ''], [t0, '0'], [t2, ["0 2"]]],
      [[nil, ''], [t1, '1'], [t2, ["1 2"]]]
    ], results[t2]
    
    assert_equal [
      [[nil, ''], [t0, '0'], [t3, ["0 3"]]],
      [[nil, ''], [t1, '1'], [t3, ["1 3"]]]
    ], results[t3]
  end
  
  def test_aggregate_join_does_not_carryover_when_aggregate_enques_task
    t0, t1, t2 = single_tracers(0,1,2)
    t3 = *splat_tracers(3)
    
    results = []
    t3.on_complete do |_result|
      unless runlist.include?('2')
        t2.enq ''
        t1.enq ''
      end
      result = _result.trail {|a| [a.key, a.value] }
      results << result
    end
    
    join.aggregate = true
    join.join([t0,t1], [t3])
    t0.enq ''
    app.run
  
    assert_equal %w{
      0 
      3
      2
      1
      3
    }, runlist
    
    assert_equal [
      [[nil, ''], [t0, '0'], [t3, ["0 3"]]],
      [[nil, ''], [t1, '1'], [t3, ["1 3"]]]
    ], results
  end
  
  def test_aggregate_join_does_not_double_execute_when_task_enques_to_aggregate_round
    t0, t1, t2 = single_tracers(0,1,2)
    t2.on_complete do |_result|
      app.queue.unshift(t1, [''])
      app.queue.unshift(t1, [''])
    end
    t3 = *splat_tracers(3)
    
    join.aggregate = true
    join.join([t0,t1], [t3])
    
    t0.enq ''
    app.queue.concat [[t2, ['']]]
    app.run
    
    assert_equal %w{
      0 
      2
      1
      1
      3
    }, runlist
    
    m0 = [[nil, ''],[t0, '0']]
    m1 = [[nil, ''],[t1, '1']]
    
    assert_equal [
      [[m0, m1, m1], [t3, ["0 3", "1 3", "1 3"]]]
    ], results[t3]
  end
end