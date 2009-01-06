# Checks the behavior of methods.  
#
# App enque and execute methods assuming that methods will 
# raise an error if they get the wrong number of arguments.  
#
# Also checks to see how the speed of a method call (.) 
# compares to a call to method.call

require 'test/unit'
require 'benchmark'

class MethodCheckClass
  def no_inputs() nil end
  def one_input(a) a end
  def two_inputs(a,b) [a,b] end
  def arb_inputs(*args) args end
  def mixed_inputs(a, b, *args) [a,b] + args end
end

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

class MethodsCheck < Test::Unit::TestCase
  include Benchmark
  
  attr_accessor :m
  
  def setup
    @m = MethodCheckClass.new
  end
  
  def test_argument_errors
    assert_raises(ArgumentError) { m.no_inputs(1) }
    
    assert_raises(ArgumentError) { m.one_input }
    assert_raises(ArgumentError) { m.one_input(1,2) }
    
    assert_raises(ArgumentError) { m.two_inputs }
    assert_raises(ArgumentError) { m.two_inputs(1) }
    assert_raises(ArgumentError) { m.two_inputs(1,2,3) }
    
    m.arb_inputs
    m.arb_inputs(1,2,3)
    
    assert_raises(ArgumentError) { m.mixed_inputs }
    assert_raises(ArgumentError) { m.mixed_inputs(1) }
    
    m.mixed_inputs(1,2)
    m.mixed_inputs(1,2,3)
  end
  
  def test_call_errors
    assert_raises(ArgumentError) { m.method(:no_inputs).call(1) }
    
    assert_raises(ArgumentError) { m.method(:one_input).call }
    assert_raises(ArgumentError) { m.method(:one_input).call(1,2) }
    
    assert_raises(ArgumentError) { m.method(:two_inputs).call }
    assert_raises(ArgumentError) { m.method(:two_inputs).call(1) }
    assert_raises(ArgumentError) { m.method(:two_inputs).call(1,2,3) }
    
    m.method(:arb_inputs).call
    m.method(:arb_inputs).call(1,2,3)
    
    assert_raises(ArgumentError) { m.method(:mixed_inputs).call }
    assert_raises(ArgumentError) { m.method(:mixed_inputs).call(1) }
    
    m.method(:mixed_inputs).call(1,2)
    m.method(:mixed_inputs).call(1,2,3)
  end
  
  def test_call_speeds_are_the_same_for_calls
    meth = m.method(:no_inputs)
    num = 1000*1000
    
    puts
    puts "all test execute #{num} times"
    puts "  * tests execute #{num/10} times"
    bm(20) do |x|
      x.report("method speed") { num.times { m.method(:no_inputs) }}
      x.report("* method + extend") { (num/10).times { m.method(:no_inputs).extend Extension }}
      x.report("exc init") { num.times { Executable.new(m, :no_inputs) }}
      x.report("* block init") { (num/10).times { ObjectWithBlock.new {} }}
      x.report("[no]block init") { num.times { ObjectWithBlock.new }}
      
      x.report("m.method") { num.times { m.no_inputs } }
      x.report("m.call") { num.times { meth.call } }
      x.report("m.send") { num.times { m.send(:no_inputs) } }
    end
  end
end