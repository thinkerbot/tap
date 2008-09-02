require File.join(File.dirname(__FILE__), 'functional_helper')

class Functional::DeclarationsTest < Test::Unit::TestCase
  
  Tap.tasc(:A) { "result" }
  
  def test_a_simple_declarations
    assert_equal Tap::Task, A.superclass
    assert_equal "result", A.new.process
  end
  
  ###########################
  
  Tap.tasc(:B, :key => 'value') { config }
  
  def test_a_simple_declaration_with_configurations
    assert_equal({:key => 'value'}, B.new.process)
    assert_equal({:key => 'value', :additional => 'config'}, B.new(:additional => 'config').process)
  end
  
  ###########################
  
  Tap.tasc(:C0) { 'result' }
  Tap.tasc(:C1 => [:C0]) { c0 }
  
  def test_a_declaration_with_dependencies
    assert_equal("c0", C0.default_name)
    assert_equal("result", C1.new.process)
    assert_equal(C1.new.process.object_id, C1.new.process.object_id)
  end
 
  ########################### 
  
  Tap.tasc(:D1 => [:D0]) { d0 }
  
  def test_undefined_dependencies_are_created
    assert_equal Tap::Task, D0.superclass
    assert_equal([], D0.new.process)
    assert_equal([], D1.new.process)
  end
  
  ########################### 
  
  Tap.tasc(:E) { [dependencies.length, config] }
  Tap.tasc(:E, :key => 'value')
  Tap.tasc(:E, :another => 'value')
  Tap.tasc(:E => [:E1])
  Tap.tasc(:E => [:E1])
  Tap.tasc(:E => [:E2])
  
  def test_dependencies_allow_extension_and_redefinition_of_classes
    assert_equal [2, {:key => 'value', :another => 'value'}], E.new.process
  end
  
  ###########################
  
  Tap.tasc(:F0) {|*args| args }
  Tap.tasc(:F => [[:F0,[1,2,3]]]) { f0 }
  
  def test_dependencies_with_argv
    assert_equal [1,2,3], F.new.process
  end
  
  ###########################
  
  Tap.tasc(:G0) {|*args| args }
  Tap.tasc(:G1) { "result" }
  Tap.tasc({:G => [[:G0,[1,2,3]], :G1, :G2]}, {:key => 'value'}) { [g0, g1, g2, config] }
  
  def test_a_complicated_declaration
    assert_equal [[1,2,3], "result", [], {:key => 'value'}], G.new.process
  end
end