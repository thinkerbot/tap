class MethodCheck
  def no_inputs() nil end
  def one_input(a) a end
  def two_inputs(a,b) [a,b] end
  def arb_inputs(*args) args end
  def mixed_inputs(a, b, *args) [a,b] + args end
end

require 'test/unit'
require 'benchmark'

class Executable
  attr_reader :source, :method_name
  def initialize(obj, method_name)
    @source = obj
    @method_name = method_name
  end
end

class ObjectWithBlock
  attr_reader :block
  def initialize(&block)
    @block = block
  end
end

module Extension
  attr_reader :batch
end

# Checks the behavior of methods.  
#
# App enque and execute methods assuming that methods will 
# raise an error if they get the wrong number of arguments.  
#
# Also checks to see how the speed of a method call (.) 
# compares to a call to method.call
class MethodCheckTest < Test::Unit::TestCase
  include Benchmark
  
  attr_accessor :m
  
  def setup
    @m = MethodCheck.new
  end
  
  def test_argument_errors
    assert_raise(ArgumentError) { m.no_inputs(1) }
    
    assert_raise(ArgumentError) { m.one_input }
    assert_raise(ArgumentError) { m.one_input(1,2) }
    
    assert_raise(ArgumentError) { m.two_inputs }
    assert_raise(ArgumentError) { m.two_inputs(1) }
    assert_raise(ArgumentError) { m.two_inputs(1,2,3) }
    
    assert_nothing_raised { m.arb_inputs }
    assert_nothing_raised { m.arb_inputs(1,2,3) }
    
    assert_raise(ArgumentError) { m.mixed_inputs }
    assert_raise(ArgumentError) { m.mixed_inputs(1) }
    assert_nothing_raised { m.mixed_inputs(1,2) }
    assert_nothing_raised { m.mixed_inputs(1,2,3) }
  end
  
  def test_call_errors
    assert_raise(ArgumentError) { m.method(:no_inputs).call(1) }
    
    assert_raise(ArgumentError) { m.method(:one_input).call }
    assert_raise(ArgumentError) { m.method(:one_input).call(1,2) }
    
    assert_raise(ArgumentError) { m.method(:two_inputs).call }
    assert_raise(ArgumentError) { m.method(:two_inputs).call(1) }
    assert_raise(ArgumentError) { m.method(:two_inputs).call(1,2,3) }
    
    assert_nothing_raised { m.method(:arb_inputs).call }
    assert_nothing_raised { m.method(:arb_inputs).call(1,2,3) }
    
    assert_raise(ArgumentError) { m.method(:mixed_inputs).call }
    assert_raise(ArgumentError) { m.method(:mixed_inputs).call(1) }
    assert_nothing_raised { m.method(:mixed_inputs).call(1,2) }
    assert_nothing_raised { m.method(:mixed_inputs).call(1,2,3) }
  end
  
  def test_call_speeds_are_the_same_for_calls
    meth = m.method(:no_inputs)
    
    bm(20) do |x|
      x.report("method speed") { (1000*1000).times { m.method(:no_inputs) }}
     # x.report("method + extend") { (1000*1000).times { m.method(:no_inputs).extend Extension }}
      x.report("exc init") { (1000*1000).times { Executable.new(m, :no_inputs) }}
      x.report("block init") { (1000*1000).times { ObjectWithBlock.new {} }}
      x.report("[no]block init") { (1000*1000).times { ObjectWithBlock.new }}
      
      0.upto(2) do |n|
        x.report("m.method #{n}") { (1000*1000).times { m.no_inputs } }
      end
      0.upto(2) do |n|
        x.report("m.call #{n}") { (1000*1000).times { meth.call } }
      end
      0.upto(2) do |n|
        x.report("m.send #{n}") { (1000*1000).times { m.send(:no_inputs) } }
      end
    end
  end
end