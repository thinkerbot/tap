require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/intern'

class InternTest < Test::Unit::TestCase

  def test_intern_documentation
    array = [1,2,3].extend Tap::Intern(:last)

    assert_equal 3, array.last
    array.last_block = lambda {|arr| arr.first }
    assert_equal 1, array.last
  end
  
  class Mock
    def m(a, b=2, *c)
      [a, b] + c
    end
    
    def n
      1
    end
  end
  
  def test_intern_calls_super_if_no_block_is_set
    mock = Mock.new
    assert_equal [1,2], mock.m(1)
    assert_equal [1,2,3,4], mock.m(1,2,3,4)
    assert_equal 1, mock.n
    
    mock.extend Tap::Intern(:m)
    assert_equal nil, mock.m_block
    
    mock.extend Tap::Intern(:n)
    assert_equal nil, mock.n_block
    
    assert_equal [1,2], mock.m(1)
    assert_equal [1,2,3,4], mock.m(1,2,3,4)
    assert_equal 1, mock.n
  end
  
  def test_intern_calls_block_with_self_and_args
    mock = Mock.new
    mock.extend Tap::Intern(:m)
    mock.m_block = lambda do |*args|
      args
    end
    
    mock.extend Tap::Intern(:n)
    mock.n_block = lambda do |*args|
      args
    end
    
    assert_equal [mock,1], mock.m(1)
    assert_equal [mock,1,2,3,4], mock.m(1,2,3,4)
    assert_equal [mock], mock.n
  end
end
