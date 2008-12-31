require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/dependencies'

class DependenciesTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :m
  
  def setup
    @m = Dependencies.new
  end
  
  #
  # register test
  #
  
  def test_register_extends_instance_with_Dependency
    d = []._method(:push)
    
    assert !d.kind_of?(Dependency)
    m.register(d)
    assert d.kind_of?(Dependency)
  end
  
  #
  # resolve test
  #

  def test_resolve_raises_error_for_circular_resolution
    d = Object.new
    
    assert_raise(Dependencies::CircularDependencyError) do
      m.resolve(d) do
        m.resolve(d) {}
      end
    end
  end
  
end