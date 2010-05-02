require File.expand_path('../../test_helper', __FILE__)
require 'tap/signals'

# These tests follow those for the DSL pattern: http://gist.github.com/181961
# Their odd construction (ex A.new.send(:key_x)) is to more closely match the
# original tests.
class SignalsInheritanceTest < Test::Unit::TestCase
  
  module X
    include Tap::Signals
    signal :key_x
    def key_x; :x; end
  end

  module Y
    include X
    signal :key_y
    def key_y; :y; end
  end

  class A
    include Y
    signal :key_a
    def key_a; :a; end
  end

  class B < A
    signal :key_b
    def key_b; :b; end
  end

  def test_signals_from_included_module_are_inherited_in_class_and_subclass
    assert_equal :x, A.new.signal(:key_x).call([])
    assert_equal :y, A.new.signal(:key_y).call([])
    assert_equal :a, A.new.signal(:key_a).call([])

    assert_equal :x, B.new.signal(:key_x).call([])
    assert_equal :y, B.new.signal(:key_y).call([])
    assert_equal :a, B.new.signal(:key_a).call([])
    assert_equal :b, B.new.signal(:key_b).call([])
  end
end

class ModifiedSignalsInheritanceTest < Test::Unit::TestCase
  module X
    include Tap::Signals
    signal :key_x
    def key_x; :x; end
  end

  module Y
    include X
    signal :key_y
    def key_y; :y; end
  end

  class A
    include Y
    signal :key_a
    def key_a; :a; end
  end

  class B < A
    signal :key_b
    def key_b; :b; end
  end

  ######################################################
  # late include into module X, and define a new method
  module LateInModule
    include Tap::Signals
    signal :key_late_in_module
    def key_late_in_module; :late_in_module; end
  end

  module X
    include LateInModule
    signal :key_late_x
    def key_late_x; :late_x; end
  end

  ######################################################
  # late include into class A, and define a new method
  module LateInClass
    include Tap::Signals
    signal :key_late_in_class
    def key_late_in_class; :late_in_class; end
  end

  class A
    include LateInClass
    signal :key_late_a
    def key_late_a; :late_a; end
  end

  ######################################################
  # define a class after late include
  class DefinedAfterLateInclude
    include X
  end

  ######################################################
  # inherit a class after late include
  class InheritAfterLateInclude < A
  end

  def test_late_inclusion_works_for_classes_but_not_modules
    assert_equal :x, A.new.signal(:key_x).call([])
    assert_equal :y, A.new.signal(:key_y).call([])
    assert_equal :a, A.new.signal(:key_a).call([])
    assert_equal :late_x, A.new.signal(:key_late_x).call([])
    assert_equal :late_a, A.new.signal(:key_late_a).call([])
    assert_equal false, A.signals.has_key?('key_method_late_in_module')
    assert_equal :late_in_class, A.new.signal(:key_late_in_class).call([])

    assert_equal :x, B.new.signal(:key_x).call([])
    assert_equal :y, B.new.signal(:key_y).call([])
    assert_equal :a, B.new.signal(:key_a).call([])
    assert_equal :b, B.new.signal(:key_b).call([])
    assert_equal :late_x, B.new.signal(:key_late_x).call([])
    assert_equal :late_a, B.new.signal(:key_late_a).call([])
    assert_equal false, B.signals.has_key?('key_method_late_in_module')
    assert_equal :late_in_class, B.new.signal(:key_late_in_class).call([])

    assert_equal :x, DefinedAfterLateInclude.new.signal(:key_x).call([])
    assert_equal :late_x, DefinedAfterLateInclude.new.signal(:key_late_x).call([])
    assert_equal :late_in_module, DefinedAfterLateInclude.new.signal(:key_late_in_module).call([])

    assert_equal :x, InheritAfterLateInclude.new.signal(:key_x).call([])
    assert_equal :y, InheritAfterLateInclude.new.signal(:key_y).call([])
    assert_equal :a, InheritAfterLateInclude.new.signal(:key_a).call([])
    assert_equal :late_x, InheritAfterLateInclude.new.signal(:key_late_x).call([])
    assert_equal :late_a, InheritAfterLateInclude.new.signal(:key_late_a).call([])
    assert_equal false, InheritAfterLateInclude.signals.has_key?('key_method_late_in_module')
    assert_equal :late_in_class, InheritAfterLateInclude.new.signal(:key_late_in_class).call([])
  end
end

class SignalsRemovalTest < Test::Unit::TestCase
  module X
    include Tap::Signals
    signal :key_x
    signal :key_y
    signal :key_z
    remove_signal :key_x
    def key_x; :x; end
    def key_y; :y; end
    def key_z; :z; end
  end
  
  module Y
    include X
  end
  
  class Z
    include Y
  end
  
  class A
    include Tap::Signals
    signal :key_a
    signal :key_b
    remove_signal :key_a
    def key_a; :a; end
    def key_b; :b; end
  end
  
  class B < A
  end
  
  class C < B
    signal :key_a
    signal :key_b
  end
  
  def test_remove_signal_removes_a_signal_defined_in_self_and_subclasses
    assert_equal false, Z.signals.has_key?('key_x')
    assert_equal :y,    Z.new.signal(:key_y).call([])
    assert_equal :z,    Z.new.signal(:key_z).call([])
    
    assert_equal false, A.signals.has_key?('key_a')
    assert_equal :b, A.new.signal(:key_b).call([])
    
    assert_equal false, B.signals.has_key?('key_a')
    assert_equal :b, B.new.signal(:key_b).call([])
  end
  
  def test_removed_signals_can_be_redefined
    assert_equal :a, C.new.signal(:key_a).call([])
    assert_equal :b, C.new.signal(:key_b).call([])
  end
  
  def test_remove_signal_raises_error_for_signal_not_defined_in_self
    err = assert_raises(NameError) { X.send(:remove_signal, :key_x) }
    assert_equal "key_x is not a signal for SignalsRemovalTest::X", err.message
    
    err = assert_raises(NameError) { Y.send(:remove_signal, :key_x) }
    assert_equal "key_x is not a signal for SignalsRemovalTest::Y", err.message
    
    err = assert_raises(NameError) { Z.send(:remove_signal, :key_z) }
    assert_equal "key_z is not a signal for SignalsRemovalTest::Z", err.message
    
    err = assert_raises(NameError) { B.send(:remove_signal, :key_b) }
    assert_equal "key_b is not a signal for SignalsRemovalTest::B", err.message
  end
end

class SignalsUndefTest < Test::Unit::TestCase
  module X
    include Tap::Signals
    signal :key_x
    signal :key_y
    signal :key_z
    undef_signal :key_x
    def key_x; :x; end
    def key_y; :y; end
    def key_z; :z; end
  end
  
  module Y
    include X
    undef_signal :key_y
  end
  
  class Z
    include Y
    undef_signal :key_z
  end
  
  class A
    include Tap::Signals
    signal :key_a
    signal :key_b
    undef_signal :key_a
    def key_a; :a; end
    def key_b; :b; end
  end
  
  class B < A
    undef_signal :key_b
  end
  
  class C < B
    signal :key_a
    signal :key_b
  end
  
  def test_undef_signal_removes_a_defined_signal_in_self_and_subclasses
    assert_equal false, Z.signals.has_key?(:key_x)
    assert_equal false, Z.signals.has_key?(:key_y)
    assert_equal false, Z.signals.has_key?(:key_z)
    
    assert_equal false, A.signals.has_key?(:key_a)
    assert_equal :b,    A.new.signal(:key_b).call([])
    
    assert_equal false, B.signals.has_key?(:key_a)
    assert_equal false, B.signals.has_key?(:key_b)
  end
  
  def test_undefined_signals_can_be_redefined
    assert_equal :a, C.new.signal(:key_a).call([])
    assert_equal :b, C.new.signal(:key_b).call([])
  end
  
  def test_undef_signal_raises_error_for_signal_not_defined_anywhere_in_ancestry
    err = assert_raises(NameError) { X.send(:undef_signal, :key_x) }
    assert_equal "key_x is not a signal for SignalsUndefTest::X", err.message
    
    err = assert_raises(NameError) { Y.send(:undef_signal, :key_unknown) }
    assert_equal "key_unknown is not a signal for SignalsUndefTest::Y", err.message
    
    err = assert_raises(NameError) { Z.send(:undef_signal, :key_unknown) }
    assert_equal "key_unknown is not a signal for SignalsUndefTest::Z", err.message
    
    err = assert_raises(NameError) { B.send(:undef_signal, :key_unknown) }
    assert_equal "key_unknown is not a signal for SignalsUndefTest::B", err.message
  end
end
