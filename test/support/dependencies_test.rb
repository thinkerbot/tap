# require File.join(File.dirname(__FILE__), 'tap_test_helper')
# require 'tap/env'
# require 'tap/support/dependencies'

# class EnvTest < Test::Unit::TestCase
#   
#   acts_as_file_test
#   
#   attr_accessor :e, :root
#   
#   def setup
#     super
# 
#     @current_load_paths = $LOAD_PATH.dup
#     $LOAD_PATH.clear
#     @current_dependencies_load_paths = Dependencies.load_paths.dup
#     Dependencies.load_paths.clear
#     
#     @e = Tap::Env.new
#     @root = Tap::Root.new
#   end
#   
#   def teardown
#     super
#     
#     Tap::Env.send(:class_variable_set, :@@instance, nil)
#     $LOAD_PATH.clear
#     $LOAD_PATH.concat(@current_load_paths)
#     Dependencies.load_paths.clear
#     Dependencies.load_paths.concat(@current_dependencies_load_paths)
#   end
#   
#   
  #
  # reload test
  #
  
  # def test_reload_returns_unloaded_constants
  #   Dependencies.clear
  #   Dependencies.load_paths << method_root
  # 
  #   assert_equal [], e.reload
  #   assert File.exists?( File.join(method_root, 'env_test_class.rb') )
  #   
  #   assert !Object.const_defined?("EnvTestClass")
  #   klass = EnvTestClass
  #     
  #   assert Object.const_defined?("EnvTestClass")
  #   assert_equal [:EnvTestClass], e.reload.collect {|c| c.to_sym }
  #   assert !Object.const_defined?("EnvTestClass")
  # end
  
  #
  # load_path_targets test
  #
  
  # def test_load_path_targets_is_LOAD_PATH_and_Dependencies_load_paths_if_using_dependencies
  #   e.use_dependencies = true
  #   assert_equal [$LOAD_PATH, Dependencies.load_paths], e.load_path_targets
  # end
