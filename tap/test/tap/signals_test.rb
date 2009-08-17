require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/signals'

class SignalsTest < Test::Unit::TestCase
  Signals = Tap::Signals
  
  #
  # signal tests
  #
  
  class SignalsClass
    include Signals
    
    def echo(*args)
      args << 'echo'
      args
    end
  end
  
  def test_signal_raises_error_for_non_existant_signal
    obj = SignalsClass.new
    err = assert_raises(RuntimeError) { obj.signal(:echo) }
    assert_equal "unknown signal: echo (SignalsTest::SignalsClass)", err.message
  end
  
  class SignalDefTest < SignalsClass
    signal :echo
  end
  
  def test_signal_creates_a_signal_for_the_specified_method
    assert SignalDefTest.signals.has_key?(:echo)
    
    obj = SignalDefTest.new
    assert_equal ["echo"], obj.signal(:echo)
    assert_equal [1,2,3, "echo"], obj.signal(:echo, [1,2,3])
  end
  
  def test_signal_symbolizes_string_sigs
    obj = SignalDefTest.new
    assert_equal ["echo"], obj.signal('echo')
  end
  
  class SignalAsTest < SignalsClass
    signal :echo, :as => :alt
  end
  
  def test_signal_as_option_aliases_signal
    assert !SignalAsTest.signals.has_key?(:echo)
    
    alt = SignalAsTest.signals[:alt]
    assert_equal :echo, alt.method_name
  end
  
  class SignalBlockTest < SignalsClass
    signal :echo do |argv|
      argv.reverse
    end
  end
  
  def test_signal_calls_method_with_block_return
    obj = SignalBlockTest.new
    assert_equal [3,2,1, "echo"], obj.signal(:echo, [1,2,3])
  end
  
  class SignalSignatureTest < SignalsClass
    signal :echo, :signature => [:a, :b, :c]
  end
  
  def test_signal_builds_argv_from_signature
    obj = SignalSignatureTest.new
    assert_equal [1,2,3, "echo"], obj.signal(:echo, :a => 1, :b => 2, :c => 3)
  end
  
  class SignalOrderTest < SignalsClass
    signal :echo, :signature => [:a, :b, :c] do |argv|
      argv.reverse
    end
  end
  
  def test_signal_sends_built_argv_to_parse
    obj = SignalOrderTest.new
    assert_equal [3,2,1, "echo"], obj.signal(:echo, :a => 1, :b => 2, :c => 3)
  end
  
  class SignalDescTest < SignalsClass
    # content...
    signal :echo  # subject
  end
  
  def test_signal_documents_description
    desc = SignalDescTest.signals[:echo].desc
    assert_equal "subject", desc.to_s
    assert_equal "content...", desc.wrap
  end
  
  class SignalConstTest < SignalsClass
    signal :a
    signal :b, :const_name => :X
    signal :c, :const_name => nil
  end
  
  def test_signal_sets_signal_as_constant_if_specified
    assert SignalConstTest.const_defined?(:A)
    assert SignalConstTest.const_defined?(:X)
    
    assert !SignalConstTest.const_defined?(:B)
    assert !SignalConstTest.const_defined?(:C)
  end
end