# require File.join(File.dirname(__FILE__), '../tap_test_helper')
# require 'tap/env'
# require 'tap/test'
# require 'rubygems'
# 
# class EnvTest < Test::Unit::TestCase
#   extend Tap::Test
#   acts_as_file_test
#   acts_as_shell_test
#   
#   Env = Tap::Env
#   
#   def setup
#     super
#     @current_env = set_env({Env::GEMS_VAR => ''}, true)
#   end
#   
#   def teardown
#     super
#     set_env(@current_env, true)
#   end
#   
#   #
#   # gems test
#   #
#   
#   class MockGem < Gem::Specification
#     attr_accessor :full_gem_path
#     def initialize(opts={})
#       super()
#       opts.each {|key, value| send("#{key}=", value) }
#     end
#   end
#   
#   def gem_test(*specs)
#     begin
#       Gem.source_index.add_specs(*specs)
#       yield
#     ensure
#       specs.each do |spec|
#         Gem.source_index.remove_spec(spec.full_name)
#       end
#     end
#   end
#   
#   def test_gem_test
#     one = MockGem.new :name => "gem_mock", :version => "1.0"
#     two = MockGem.new :name => "gem_mock", :version => "2.0"
#     three = MockGem.new :name => "mock_gem", :version => "1.0"
#     
#     dep_one_two = Gem::Dependency.new("gem_mock", ">= 1.0")
#     dep_two = Gem::Dependency.new("gem_mock", "> 1.0")
#     assert_equal [], Gem.source_index.search(dep_one_two)
#     
#     was_in_block = false
#     gem_test(one, two, three) do
#       assert_equal [one, two], Gem.source_index.search(dep_one_two)
#       assert_equal [two], Gem.source_index.search(dep_two)
#       was_in_block = true
#     end
#     
#     assert_equal [], Gem.source_index.search(dep_one_two)
#     assert was_in_block
#   end
#   
#   #
#   # Env.setup test
#   #
#   
#   def test_setup_sets_up_paths_for_dir
#     env = Env.setup(method_root.path)
#     assert_equal [method_root.path, Env::HOME], env.paths.collect {|path| path.base }
#   end
#   
#   def test_setup_sets_up_paths_as_specified_in_options
#     env = Env.setup(method_root.path, :env_path => 'a:b/c')
#     assert_equal [
#       method_root.path('a'),
#       method_root.path('b/c'),
#       Env::HOME
#     ], env.paths.collect {|path| path.base }
#   end
#   
#   def test_setup_sets_up_paths_for_ENV_PATH_VAR_if_specified
#     set_env Env::ENV_PATH_VAR => 'a:b/c'
#     
#     env = Env.setup(method_root.path)
#     assert_equal [
#       method_root.path('a'),
#       method_root.path('b/c'),
#       Env::HOME
#     ], env.paths.collect {|path| path.base }
#   end
#   
#   def test_setup_adds_gems_as_specified_in_gems
#     one = MockGem.new(
#       :name => "a", :version => "1.0", 
#       :full_gem_path => method_root.path('a-1.0'))
#     two = MockGem.new(
#       :name => "b", :version => "1.0", 
#       :full_gem_path => method_root.path('b-1.0'))
#     
#     gem_test(one, two) do
#       env = Env.setup(method_root.path, :gems => [one, two])
#       assert_equal [
#         method_root.path,
#         method_root.path('a-1.0'),
#         method_root.path('b-1.0'),
#         Env::HOME
#       ], env.paths.collect {|path| path.base }
#     end
#   end
#   
#   def test_setup_adds_gem_paths_as_specified_in_GEMS_VAR
#     one = MockGem.new(
#       :name => "a", :version => "1.0", 
#       :full_gem_path => method_root.path('a-1.0'))
#     two = MockGem.new(
#       :name => "a", :version => "2.0",
#       :full_gem_path => method_root.path('a-2.0'))
#     three = MockGem.new(
#       :name => "b", :version => "1.0", 
#       :full_gem_path => method_root.path('b-1.0'))
#     
#     gem_test(one, two, three) do
#       set_env Env::GEMS_VAR => 'a > 1.0:b'
#       
#       env = Env.setup(method_root.path)
#       assert_equal [
#         method_root.path,
#         method_root.path('a-2.0'),
#         method_root.path('b-1.0'),
#         Env::HOME
#       ], env.paths.collect {|path| path.base }
#     end
#   end
#   
#   def test_setup_loads_path_map_from_Path_FILE_under_each_path
#     set_env Env::ENV_PATH_VAR => 'a:b/c'
#     
#     method_root.prepare('a', Env::Path::FILE) do |io|
#       io << YAML.dump('dir' => 'A')
#     end
#     
#     method_root.prepare('b/c', Env::Path::FILE) do |io|
#       io << YAML.dump('dir' => ['B', 'C'])
#     end
#     
#     env = Env.setup(method_root.path)
#     assert_equal [
#       [method_root.path('a/A')],
#       [method_root.path('b/c/B'), method_root.path('b/c/C')], 
#       [File.expand_path('dir', Env::HOME)]
#     ], env.paths.collect {|path| path['dir'] }
#   end
# end