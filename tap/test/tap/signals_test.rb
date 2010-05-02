require File.expand_path('../../test_helper', __FILE__)
require 'tap/signals'

class SignalsTest < Test::Unit::TestCase
  acts_as_tap_test
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
    
    def echo_hash(argh)
      argh['echo'] = true
      argh
    end
  end
  
  def test_signal_raises_error_for_non_existant_signal
    obj = SignalsClass.new
    err = assert_raises(RuntimeError) { obj.signal('echo') }
    assert_equal "unknown signal: echo (SignalsTest::SignalsClass)", err.message
  end
  
  class SignalDefTest < SignalsClass
    signal :echo
    signal :echo_hash
  end
  
  def test_signal_creates_a_signal_bound_to_the_specified_method
    assert SignalDefTest.signals.has_key?('echo')
    
    obj = SignalDefTest.new
    assert_equal ["echo"], obj.signal('echo').call([])
    assert_equal [1,2,3, "echo"], obj.signal('echo').call([1,2,3])
    assert_equal({:key => :value, 'echo' => true}, obj.signal('echo_hash').call([{:key => :value}]))
    
    err = assert_raises(ArgumentError) { obj.signal('echo_hash').call([1, 2]) }
    
    assert [
      "wrong number of arguments (2 for 1)",
      "wrong # of arguments(2 for 1)",
      "method 'echo_hash': given 2, expected 1",
    ].include?(err.message), err.message
  end
  
  def test_signal_stringifies_sig
    obj = SignalDefTest.new
    assert_equal ["echo"], obj.signal(:echo).call([])
  end
  
  #
  # signal options
  #
  
  class SignalTest < SignalsClass
    signal :alt, :bind => :echo
  end
  
  def test_bind_specifies_bound_method
    assert !SignalTest.signals.has_key?('echo')
    
    obj = SignalTest.new
    assert_equal [1,2,3, "echo"], obj.signal('alt').call([1,2,3])
  end
  
  class SignalBlockTest < SignalsClass
    signal :echo do |sig, argv|
      argv.reverse
    end
  end
  
  def test_signal_calls_method_with_block_return
    obj = SignalBlockTest.new
    assert_equal [3,2,1, "echo"], obj.signal('echo').call([1,2,3])
  end
  
  class SignalWithoutMethodTest < SignalsClass
    signal :sig, :bind => nil do |sig, argv|
      argv << "was in block"
      argv
    end
  end
  
  def test_signals_return_block_return_if_not_bound_to_a_method
    res = SignalWithoutMethodTest.new.signal('sig').call([1,2,3])
    assert_equal [1,2,3, "was in block"], res
  end
  
  class SignalSignatureTest < SignalsClass
    signal :echo, :signature => [:a, :b, :c]
  end
  
  def test_signal_builds_argv_from_hash_signature
    obj = SignalSignatureTest.new
    assert_equal [1,2,3, "echo"], obj.signal('echo').call(:a => 1, :b => 2, :c => 3)
  end
  
  class SignalSignatureWithRemainderTest < SignalsClass
    signal :echo, :signature => [:a, :b], :remainder => true
  end
  
  def test_signal_passes_remaining_args_as_options
    obj = SignalSignatureWithRemainderTest.new
    assert_equal [1,2, {:c => 3}, "echo"], obj.signal('echo').call(:a => 1, :b => 2, :c => 3)
  end
  
  class SignalOrderTest < SignalsClass
    signal :echo, :signature => [:a, :b, :c] do |sig, argv|
      argv.reverse
    end
  end
  
  def test_signal_sends_built_argv_to_parse
    obj = SignalOrderTest.new
    assert_equal [3,2,1, "echo"], obj.signal('echo').call(:a => 1, :b => 2, :c => 3)
  end
  
  #
  # signal_hash test
  #
  
  class SignalHashSignatureTest < SignalsClass
    signal_hash :echo_hash, :signature => [:a, 'b', :c]
  end
  
  def test_signal_hash_builds_argh_from_array_signature
    obj = SignalHashSignatureTest.new
    assert_equal({
      :a => 1, 
      'b' => 2, 
      :c => 3, 
      'echo' => true
    }, obj.signal(:echo_hash).call([1,2,3]))
  end
  
  class SignalHashArgsTest < SignalsClass
    signal_hash :echo_hash, :signature => [:a], :remainder => :args
  end
  
  def test_signal_hash_adds_remaining_args_to_remainder_if_specified
    obj = SignalHashArgsTest.new
    assert_equal({
      :a => 1, 
      :args => [2,3],
      'echo' => true
    }, obj.signal(:echo_hash).call([1,2,3]))
    
    assert_equal({
      :a => 1, 
      :args => [],
      'echo' => true
    }, obj.signal(:echo_hash).call([1]))
  end
  
  class SignalHashOrderTest < SignalsClass
    signal_hash :echo_hash, :signature => [:a, :b, :c] do |sig, argh|
      argh['was_in_block'] = true
      argh
    end
  end
  
  def test_signal_hash_sends_built_argh_to_parse
    obj = SignalHashOrderTest.new
    assert_equal({
      :a => 1,
      :b => 2, 
      :c => 3, 
      'echo' => true, 
      'was_in_block' => true
    }, obj.signal(:echo_hash).call([1,2,3]))
  end
  
  #
  # define_signal options
  #
  
  class SignalClassTest
    include Signals
    
    define_signal :key do |input|
      input << "was in block"
      input
    end
  end
  
  def test_define_signal_creates_signal_subclass
    assert SignalClassTest.signals.has_key?('key')
    
    obj = SignalClassTest.new
    assert_equal [1,2,3, "was in block"], obj.signal('key').call([1,2,3])
  end
  
  class SignalSubClassTest
    include Signals
    
    class Sub < Tap::Signal
      def process(argv)
        argv << "was in process"
        argv
      end
    end
    
    define_signal :key, Sub
  end
  
  def test_define_signal_sets_class_if_no_block_is_specified
    assert SignalSubClassTest.signals.has_key?('key')
    
    obj = SignalSubClassTest.new
    sig = obj.signal('key')
    assert_equal SignalSubClassTest::Key, sig.class
    assert_equal SignalSubClassTest::Sub, sig.class.superclass
    assert_equal [1,2,3, "was in process"], sig.call([1,2,3])
  end
  
  #
  # remove_signal test
  #
  
  class RemoveSignal
    include Tap::Signals
    signal :a
    signal :b
  end
  
  def test_remove_signal_removes_constant_if_specified
    assert_equal true, RemoveSignal.const_defined?(:A)
    RemoveSignal.send(:remove_signal, :a)
    assert_equal(["b"], RemoveSignal.signals.keys)
    assert_equal false, RemoveSignal.const_defined?(:A)
    
    RemoveSignal.send(:remove_signal, :b, :remove_const => false)
    assert_equal([], RemoveSignal.signals.keys)
    assert_equal true, RemoveSignal.const_defined?(:B)
  end
  
  class CachedRemoveSignal
    include Tap::Signals
    signal :a
    signal :b
    
    cache_signals
  end
  
  def test_remove_signal_recaches_cached_signals
    assert_equal(["a", "b"], CachedRemoveSignal.signals.keys)
    CachedRemoveSignal.send(:remove_signal, :a)
    assert_equal(["b"], CachedRemoveSignal.signals.keys)
  end
  
  class NoCacheRemoveSignal
    include Tap::Signals
    signal :a
    signal :b
  end
  
  def test_remove_signal_does_not_accidentally_cache_uncached_signals
    NoCacheRemoveSignal.send(:remove_signal, :a)
    assert NoCacheRemoveSignal.signals.object_id != NoCacheRemoveSignal.signals.object_id
  end
  
  #
  # undef_signal test
  #
  
  class UndefSignal
    include Tap::Signals
    signal :a
    signal :b
  end
  
  def test_undef_signal_removes_constant_if_specified
    assert_equal true, UndefSignal.const_defined?(:A)
    UndefSignal.send(:undef_signal, :a)
    assert_equal(["b"], UndefSignal.signals.keys)
    assert_equal false, UndefSignal.const_defined?(:A)
    
    UndefSignal.send(:undef_signal, :b, :remove_const => false)
    assert_equal([], UndefSignal.signals.keys)
    assert_equal true, UndefSignal.const_defined?(:B)
  end
  
  class CachedUndefSignal
    include Tap::Signals
    signal :a
    signal :b
    
    cache_signals
  end
  
  def test_undef_signal_recaches_cached_signals
    assert_equal(["a", "b"], CachedUndefSignal.signals.keys)
    CachedUndefSignal.send(:undef_signal, :a)
    assert_equal(["b"], CachedUndefSignal.signals.keys)
  end
  
  class NoCacheUndefSignal
    include Tap::Signals
    signal :a
    signal :b
  end
  
  def test_undef_signal_does_not_accidentally_cache_uncached_signals
    NoCacheUndefSignal.send(:undef_signal, :a)
    assert NoCacheUndefSignal.signals.object_id != NoCacheUndefSignal.signals.object_id
  end
  
  #
  # signal documentation
  #
  
  class SignalDescTest < SignalsClass
    # content...
    signal :echo  # subject
  end
  
  def test_signal_documents_description
    desc = SignalDescTest.signals['echo'].desc
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
  
  #
  # inheritance
  #
  
  class SignalParent < SignalsClass
    signal :a
    signal :b
  end
  
  class SignalChild < SignalParent
    signal :b
    signal :c
  end
  
  def test_signals_are_inherited
    assert_equal true, SignalParent.signals.has_key?('a')
    assert_equal true, SignalParent.signals.has_key?('b')
    assert_equal false, SignalParent.signals.has_key?('c')
    
    assert_equal true, SignalChild.signals.has_key?('a')
    assert_equal true, SignalChild.signals.has_key?('b')
    assert_equal true, SignalChild.signals.has_key?('c')
  end
  
  def test_signals_can_be_overridden
    assert_equal SignalParent::A, SignalParent.signals['a']
    assert_equal SignalParent::B, SignalParent.signals['b']
    
    assert_equal SignalParent::A, SignalChild.signals['a']
    assert_equal SignalChild::B, SignalChild.signals['b']
  end
  
end