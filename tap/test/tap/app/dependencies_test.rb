require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/dependencies'

class DependenciesTest < Test::Unit::TestCase
  Dependency = Tap::App::Dependency
  Dependencies = Tap::App::Dependencies
  
  attr_accessor :d
  
  def setup
    @d = Dependencies.new
  end
  
  
  #
  # resolve test
  #

  def test_resolve_yields_to_the_block
    was_in_block = false
    d.resolve(:obj) { was_in_block = true }
    
    assert was_in_block
  end
  
  def test_resolve_may_be_called_recursively
    stack = []
    d.resolve(:a) do 
      stack << 'A'
      
      d.resolve(:b) do
        stack << 'B'
        
        d.resolve(:c) do
          stack << 'C'
        end
      end
    end
    
    assert_equal ['A', 'B', 'C'], stack
  end
  
  def test_resolve_raises_error_for_circular_dependencies
    stack = []
    err = assert_raises(Dependencies::CircularDependencyError) do
      d.resolve(:a) do 
        stack << 'A'
        
        d.resolve(:b) do
          stack << 'B'
          
          d.resolve(:a) do
            stack << 'C'
          end
        end
      end
    end
    
    assert_equal ['A', 'B'], stack
    assert_equal "circular dependency: [a, b, a]", err.message
  end
  
end