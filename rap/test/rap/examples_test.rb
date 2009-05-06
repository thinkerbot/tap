$:.unshift File.expand_path("#{File.dirname(__FILE__)}/../../tap/lib")
require 'test/unit'
require 'rap/declarations'
require 'stringio'

class ExamplesTest < Test::Unit::TestCase
  extend Rap::Declarations
  
  attr_reader :trace
  
  def setup
    @current_stdout = $stdout
    @trace = ""
    $stdout = StringIO.new(@trace)
  end
  
  def teardown
    $stdout = @current_stdout
  end
  
  task(:A) { print "result" }
  
  def test_declarations_subclass_DeclarationTask
    assert_equal Rap::DeclarationTask, A.superclass
  end
  
  def test_declarations_add_action_to_subclass
    assert_equal nil, A.instance.execute
    assert_equal "result", trace
  end
  
  ###########################
  
  task(:B, :key => 'value')
  
  def test_declaration_adds_configs_to_subclass
    assert_equal({:key => 'value'}, B.instance.config.to_hash)
  end
  
  task(:C, :one => 1)
  task(:C, :two => 2)
  
  def test_configs_may_be_added_in_multiple_calls
    assert_equal({:one => 1, :two => 2}, C.instance.config.to_hash)
  end
  
  ###########################
  
  task(:D1 => [:D0])
  
  def test_declaration_declares_new_dependencies
    assert_equal Rap::DeclarationTask, D0.superclass
  end
  
  def test_declaration_adds_dependencies
    assert_equal [D0], D1.dependencies
  end
   
  ########################### 
  
  task(:E2 => :E0)
  task(:E2 => :E1)
  
  def test_dependencies_may_be_added_in_multiple_calls
    assert_equal [E0, E1], E2.dependencies
  end
  
  ########################### 
  
  task(:F) { print "0" }
  task(:F) { print "1" }
  task(:F) { print "2" }
  
  def test_actions_may_be_added_in_multiple_calls
    F.instance.execute
    assert_equal "012", trace
  end

  ###########################
  
  namespace(:G) do
    task(:G)
  end
  
  def test_namespaces_nest_a_task
    assert_equal Rap::DeclarationTask, G::G.superclass
  end
  
  ###########################
  
  Rap.task(:existant)
  Rap.namespace(:nest) do
    # reference an existant, non-nested task
    Rap.task(:existant => 'existant')
    
    # reference a non-existant non-nested task
    Rap.task(:existant => 'non_existant')
  end
  
  Rap.task(:ref => 'existant')
  Rap.task(:ref => 'non_existant')
  Rap.task(:ref => 'nest:existant')
  Rap.task(:ref => 'nest:non_existant_task')
  Rap.task(:ref => 'non_existant_nest:non_existant_task')
  
  def test_namespaces_are_resolved_in_dependencies
    assert_equal [
      Existant, 
      NonExistant, 
      Nest::Existant, 
      Nest::NonExistantTask, 
      NonExistantNest::NonExistantTask
    ], Ref.dependencies
    
    assert_equal [
      Existant, 
      NonExistant
    ], Nest::Existant.dependencies
  end
end