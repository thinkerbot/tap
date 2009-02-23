require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/exe'

class ExeTest < Test::Unit::TestCase
  include Tap
  
  acts_as_file_test
  
  attr_accessor :e
  
  def setup
    super
    
    @current_instance = Env.instance
    @current_instances = Env.instances
    Env.send(:class_variable_set, :@@instance, nil)
    Env.send(:class_variable_set, :@@instances, {})
    
    @current_load_paths = $LOAD_PATH.dup
    $LOAD_PATH.clear

    @e = Exe.new
  end
  
  def teardown
    super
    
    Env.send(:class_variable_set, :@@instance,  @current_instance)
    Env.send(:class_variable_set, :@@instances, @current_instances)
    
    $LOAD_PATH.clear
    $LOAD_PATH.concat(@current_load_paths)
  end
  
  #
  # initialization tests
  #
  
  def test_Exes_may_be_initialized_from_paths
    e = Exe.new(".")
    assert_equal Dir.pwd, e.root.root
  end
  
  #
  # activate test
  #
  
  def test_activate_requires_requires_after_setting_load_paths
    e.load_paths = [method_root[:lib]]
  
    a = method_root.filepath('require_a')
    b = 'require_b'
    e.requires = [a,b]
  
    assert !Object.const_defined?(:RequireA)
    assert !Object.const_defined?(:RequireB)
  
    e.activate
  
    assert Object.const_defined?(:RequireA)
    assert Object.const_defined?(:RequireB)
  end
end