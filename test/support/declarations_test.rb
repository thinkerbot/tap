require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/declarations'

Tap.extend Tap::Support::Declarations

class DeclarationsTest < Test::Unit::TestCase
  include Tap::Support::Declarations
  
  module Nest
    extend Tap::Support::Declarations
    tasc(:sample) {}
  end
 
  def test_declarations_nest_constant
    const = tasc(:sample) {}
    assert_equal "DeclarationsTest::Sample", const.to_s
    
    assert Nest.const_defined?("Sample")
  end
  
  def test_declarations_are_not_nested_for_tap
    const = Tap.tasc(:sample_declaration) {}
    assert_equal "SampleDeclaration", const.to_s
  end

end