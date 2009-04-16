require File.join(File.dirname(__FILE__), '../app_test_helper')
require 'tap/join'

class JoinTest < Test::Unit::TestCase
  include JoinTestMethods
  Join = Tap::Join
  
  attr_accessor :join
  
  def setup
    super
    @join = Join.new({}, app)
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
    assert_equal({:iterate => true, :enq => true}, Join.parse_modifier("iq"))
  end

  def test_parse_modifier_raises_error_for_unknown_options
    assert_raises(RuntimeError) { Join.parse_modifier("p") }
  end
  
  #
  # join tests
  #
  
  def test_simple_join
    t0 = single(0)
    t1 = single(1)
    t2 = single(2)
    t3 = single(3)
    
    join.join([t0,t1], [t2,t3])
    app.enq t0, ''
    app.enq t1, ''
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
  
  def test_enq_join
    t0 = single(0)
    t1 = single(1)
    t2 = single(2)
    t3 = single(3)
    
    join.enq = true
    join.join([t0,t1], [t2,t3])
    app.enq t0, ''
    app.enq t1, ''
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
  
  def test_iterate_splat_join
    t0 = array(0)
    t1 = array(1)
    t2 = single(2)
    t3 = single(3)
    
    join.iterate = true
    join.splat = true
    join.join([t0,t1], [t2,t3])
    app.enq t0, ['a', 'b']
    app.enq t1, ['c', 'd']
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
    t0 = array(0)
    t1 = array(1)
    t2 = splat(2)
    t3 = splat(3)
    
    join.splat = true
    join.join([t0,t1], [t2,t3])
    
    app.enq t0, ['a', 'b']
    app.enq t1, ['c', 'd']
    app.run
  
    assert_equal %w{
      0 2 3
      1 2 3
    }, runlist
    
    m0a = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [0, "a 0"]]
    m0b = [[nil, ["a", "b"]], [t0, ["a 0", "b 0"]], [1, "b 0"]]
    m1a = [[nil, ["c", "d"]], [t1, ["c 1", "d 1"]], [0, "c 1"]]
    m1b = [[nil, ["c", "d"]], [t1, ["c 1", "d 1"]], [1, "d 1"]]
    
    assert_equal [
      [[m0a, m0b], [t2, ['a 0 2', 'b 0 2']]],
      [[m1a, m1b], [t2, ['c 1 2', 'd 1 2']]]
    ], results[t2]
    
    assert_equal [
      [[m0a, m0b], [t3, ['a 0 3', 'b 0 3']]],
      [[m1a, m1b], [t3, ['c 1 3', 'd 1 3']]]
    ], results[t3]
  end
end