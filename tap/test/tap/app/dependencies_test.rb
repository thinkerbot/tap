require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/dependencies'

class DependenciesTest < Test::Unit::TestCase
  Dependencies = Tap::App::Dependencies
  Dependency = Tap::App::Dependency
  
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
    
    assert_raises(Dependencies::CircularDependencyError) do
      m.resolve(d) do
        m.resolve(d) {}
      end
    end
  end
  
end