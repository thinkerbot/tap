require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/exe'

class ExeTest < Test::Unit::TestCase
  include MethodRoot
  
  Exe = Tap::Exe
  
  def setup
    super
    Tap::Env.instance = nil
  end
  
  #
  # setup test
  #
  
  def test_setup_returns_env
    assert Exe.setup.kind_of?(Tap::Env)
  end
  
  def test_setup_sets_dir_as_env_root
    exe = Exe.setup :dir => method_root[:dir], :config_file => nil
    assert_equal method_root[:dir], exe.root.root
  end
  
  def test_setup_loads_configs_from_dir_config_file
    method_root.prepare('config.yml') do |io|
      io << "key: value"
    end
    exe = Exe.setup :dir => method_root.root, :config_file => 'config.yml'
    assert_equal 'value', exe.config[:key]
  end
  
  def test_setup_loads_configs_from_ENV
    exe = Exe.setup({:dir => method_root.root, :config_file => nil}, [], {'TAP_KEY' => 'value'})
    assert_equal 'value', exe.config[:key]
    
    current = {}
    ENV.each_pair do |key, value|
      current[key] = value
    end
    
    begin
      ENV.clear
      ENV['TAP_KEY'] = "value"
      exe = Exe.setup :dir => method_root.root, :config_file => nil
      assert_equal 'value', exe.config[:key]
    ensure
      ENV.clear
      current.each_pair do |key, value|
        ENV[key] = value
      end
    end
  end
  
  def test_setup_merges_default_global_user_options
    method_root.prepare('config.yml') do |io|
      io << "key: user"
    end
    
    exe = Exe.setup :dir => method_root.root, :config_file => nil
    assert_equal nil, exe.config[:key]
    
    exe = Exe.setup({:dir => method_root.root, :config_file => nil}, [], {'TAP_KEY' => 'global'})
    assert_equal 'global', exe.config[:key]
    
    exe = Exe.setup({:dir => method_root.root, :config_file => 'config.yml'}, [], {'TAP_KEY' => 'global'})
    assert_equal 'user', exe.config[:key]
    
    exe = Exe.setup({:dir => method_root.root, :config_file => 'config.yml', 'key' => 'options'}, [], {'TAP_KEY' => 'global'})
    assert_equal 'options', exe.config[:key]
  end
  
  def test_setup_sets_DEBUG_if_ARGV_ends_in_superopt
    current = $DEBUG
    begin
      $DEBUG = false
      argv = [1,2,3,"-d-"]
      Exe.setup({}, argv)
      
      assert_equal [1,2,3], argv
      assert_equal true, $DEBUG
    ensure
      $DEBUG = current
    end
  end
end