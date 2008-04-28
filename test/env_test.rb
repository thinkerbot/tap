require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/env'

class ConfigurationTest < Test::Unit::TestCase
  include Tap::Env::Configuration
  
  acts_as_file_test
  
  #
  # read_config test 
  #
  
  def test_read_config_templates_then_loads_config
    config_file = output_tempfile
    
    File.open(config_file, "wb") {|f| f << "sum: <%= 1 + 2 %>" }
    assert_equal({'sum' => 3}, read_config(config_file))
  end
  
  def test_read_config_returns_empty_hash_for_non_existant_nil_and_false_files
    config_file = output_tempfile
    
    assert !File.exists?(config_file)
    assert_equal({}, read_config(config_file))
    
    FileUtils.touch(config_file)
    assert_equal({}, read_config(config_file))
    
    File.open(config_file, "wb") {|f| f << nil.to_yaml }
    assert_equal(nil, YAML.load_file(config_file))
    assert_equal({}, read_config(config_file))
    
    File.open(config_file, "wb") {|f| f << false.to_yaml }
    assert_equal(false, YAML.load_file(config_file))
    assert_equal({}, read_config(config_file))
  end
  
  def test_read_config_raises_error_for_non_hash_result
    config_file = output_tempfile
    File.open(config_file, "wb") {|f| f << [].to_yaml }
    
    assert_raise(RuntimeError) { read_config(config_file) }
  end
  
  #
  # partition_configs test
  #
  
  def test_partition_configs
    config = {'before' => :b, 'gems' => :g, 'root' => :r, 'another' => :a}
    
    env, app, other = partition_configs(config, ['gems'], ['root', 'another'])
    assert_equal({'gems' => :g}, env)
    assert_equal({'root' => :r, 'another' => :a}, app)
    assert_equal({'before' => :b}, other)
  end
  
  #
  # join_configs test
  #
  
  def test_join_configs
    a = {:a => 1, :b => [1]}
    b = {:a => [2], :b => [1]}
    c = {:c => 1}
    
    assert_equal({:a => [1, 2], :b => [1], :c => [1]}, join_configs(a,b,c))
    assert_equal({:a => [2, 1], :b => [1], :c => [1]}, join_configs(c,b,a))
  end
end

class EnvTest < Test::Unit::TestCase
  
  acts_as_file_test
  attr_accessor :e
  
  def setup
    super
    @e = Tap::Env.instance
    e.reset
  end
  
  def teardown
    super
    e.reset
  end
  
  #
  # load_env_config test
  #
  
  def test_load_env_config
    empty_config = {
      "load_paths" => [],
      "load_once_paths" => [],
      "config_paths" => [],
      "command_paths" => [],
      "gems" => [],
      "generator_paths" => []
    }
    starting_load_paths = $:.uniq
    
    assert_equal(empty_config, e.config)
    assert Dependencies.load_paths.empty?
    assert Dependencies.load_once_paths.empty?
  
    # test specifying a file
    assert File.exists?(method_filepath('tap.yml'))
    e.load_config(method_filepath('tap.yml'))
    
    assert_equal({
      "load_paths" => [method_filepath('lib'), method_filepath('nested/lib')],
      "load_once_paths" => [method_filepath('lop.rb'), method_filepath('nested/lop.rb')],
      "config_paths" => [method_filepath('tap.yml')],
      "command_paths" => [method_filepath('cmd'), method_filepath('nested/cmd')],
      "gems" => [],
      "generator_paths" => [method_filepath('lib/generators')]
    }, e.config)
    
    assert_equal [], e.config['load_paths'] - $:
    assert_equal e.config['load_paths'], Dependencies.load_paths
    assert_equal e.config['load_once_paths'], Dependencies.load_once_paths

    # test specifying a dir
    assert File.exists?(method_filepath('dir', 'tap.yml'))
    e.load_config(method_filepath('dir'))
    
    assert_equal({
      "load_paths" => [method_filepath('dir/lib'), method_filepath('dir/nested/lib'), method_filepath('lib'), method_filepath('nested/lib')],
      "load_once_paths" => [ method_filepath('dir/lop.rb'), method_filepath('dir/nested/lop.rb'), method_filepath('lop.rb'), method_filepath('nested/lop.rb')],
      "config_paths" => [method_filepath('tap.yml'), method_filepath('dir', 'tap.yml')],
      "command_paths" => [method_filepath('dir/cmd'), method_filepath('dir/nested/cmd'), method_filepath('cmd'), method_filepath('nested/cmd')],
      "gems" => [],
      "generator_paths" => [method_filepath('dir/lib/generators'), method_filepath('lib/generators')]
    }, e.config)
    
    assert_equal [], e.config['load_paths'] - $:
    assert_equal e.config['load_paths'], Dependencies.load_paths
    assert_equal e.config['load_once_paths'], Dependencies.load_once_paths

    # add extra Dependencies load paths to be sure ONLY the ENV load paths are cleared
    Dependencies.load_paths << 'extra'
    Dependencies.load_once_paths << 'extra'
    
    # test reset
    e.reset
    assert_equal(empty_config, e.config)
    assert_equal ['extra'], Dependencies.load_paths
    assert_equal ['extra'], Dependencies.load_once_paths
    assert_equal starting_load_paths, $:
    
    # test recursion/config_path loading
    pwd = Dir.pwd
    begin
      Dir.chdir(method_root)
      e.load_config('recurse_a.yml')
    ensure
      Dir.chdir(pwd)
    end
    
    assert_equal [method_filepath('lib'), method_filepath('nested/lib')], e.config['load_paths']
    assert_equal [method_filepath('recurse_a.yml'), method_filepath('recurse_b.yml')], e.config['config_paths']
  end
  
  #
  # configure test
  #
  
  # def test_configure
  #   assert e.load_paths.empty?
  #   assert e.command_paths.empty?
  #   assert e.load_once_paths.empty?
  #   assert e.config_paths.empty?
  #   assert_nil e.before
  #   assert_nil e.after
  #   assert_equal Tap::App.instance, e.app
  #   
  #   pwd = Dir.pwd
  #   begin
  #     Dir.chdir(method_root)
  #     e.configure
  #   ensure
  #     Dir.chdir(pwd)
  #   end
  #   
  #   app = e.app
  # 
  #   assert_equal [method_filepath('lib'), method_filepath('dir'), method_filepath('a'), method_filepath('b')], e.load_paths
  #   assert_equal [method_filepath('cmd')], e.command_paths
  #   assert_equal [], e.load_once_paths
  #   assert_equal [method_filepath('tap.yml'), method_filepath('recurse_a.yml'), method_filepath('recurse_b.yml')], e.config_paths
  #   assert_equal "before\n", e.before
  #   assert_equal nil, e.after
  #   
  #   assert_equal({'rel' => 'dir'}, app.directories)
  #   assert app.options.quiet
  # end
end