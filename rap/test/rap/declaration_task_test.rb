require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declarations'

class DeclarationTaskTest < Test::Unit::TestCase
  include Rap
  
  def setup
    Rap::Declarations.env = Tap::Env.new(:load_paths => [], :command_paths => [], :generator_paths => [])
  end
  
  def teardown
    0.upto(3) do |n|    
      const_name = "Task#{n}".to_sym
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    end
  end
  
  #
  # declare test
  #
  
  def test_declare_raises_error_if_it_looks_up_a_non_DeclarationTask_class
    e = assert_raises(RuntimeError) { DeclarationTask.declare(:Object) }
    assert_equal "not a DeclarationTask: Object", e.message
  end
  
  #
  # register_desc test
  #
  
  def test_register_desc_registers_description_for_task
    
    # comment
    DeclarationTask.declare(:task0).register_desc("description")
    
    assert_equal "description", Task0.manifest.desc
    assert_equal "comment", Task0.manifest.comment
  end
end