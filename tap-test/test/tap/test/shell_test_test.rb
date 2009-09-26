require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test/shell_test'

class ShellTestSample < Test::Unit::TestCase
  include Tap::Test::ShellTest
  
  self.sh_test_options = {
    :cmd_pattern => '% inspect_argv',
    :cmd => 'ruby -e "puts ARGV.inspect"'
  }
  
  def test_echo
    assert_equal "goodnight moon", sh("echo goodnight moon").strip
  end

  def test_inspect_argv
    sh_test("% inspect_argv a b c") do |output|
      assert_equal %Q{["a", "b", "c"]\n}, output
    end

    sh_test %q{
% inspect_argv a b c
["a", "b", "c"]
}
  end
end

class ShellTestTest < Test::Unit::TestCase
  include Tap::Test::ShellTest
  
  #
  # quiet, verbose test
  #
  
  def test_verbose_is_true_if_VERBOSE_is_truish
    with_env 'VERBOSE' => 'true' do
      assert_equal true, verbose?
    end
    
    with_env 'VERBOSE' => 'TruE' do
      assert_equal true, verbose?
    end
    
    with_env 'VERBOSE' => 'false' do
      assert_equal false, verbose?
    end
    
    with_env 'VERBOSE' => nil do
      assert_equal false, verbose?
    end
  end
  
  def test_quiet_is_true_if_QUIET_is_truish
    with_env 'QUIET' => 'true' do
      assert_equal true, quiet?
    end
    
    with_env 'QUIET' => 'TruE' do
      assert_equal true, quiet?
    end
    
    with_env 'QUIET' => 'false' do
      assert_equal false, quiet?
    end
    
    with_env 'QUIET' => nil do
      assert_equal false, quiet?
    end
  end
  
  def test_verbose_wins_over_quiet
    with_env 'VERBOSE' => 'true', 'QUIET' => 'true' do
      assert_equal true, verbose?
      assert_equal false, quiet?
    end
  end
  
  #
  # with_env test
  #
  
  def test_with_env_sets_variables_for_duration_of_block
    assert_equal nil, ENV['UNSET_VARIABLE']
    ENV['SET_VARIABLE'] = 'set'
    
    was_in_block = false
    with_env 'UNSET_VARIABLE' => 'unset' do
      was_in_block = true
      assert_equal 'set', ENV['SET_VARIABLE']
      assert_equal 'unset', ENV['UNSET_VARIABLE']
    end
    
    assert_equal true, was_in_block
    assert_equal 'set', ENV['SET_VARIABLE']
    assert_equal nil, ENV['UNSET_VARIABLE']
    assert_equal false, ENV.has_key?('UNSET_VARIABLE')
  end
  
  def test_with_env_resets_variables_even_on_error
    assert_equal nil, ENV['UNSET_VARIABLE']
    
    was_in_block = false
    err = assert_raises(RuntimeError) do
      with_env 'UNSET_VARIABLE' => 'unset' do
        was_in_block = true
        assert_equal 'unset', ENV['UNSET_VARIABLE']
        raise "error"
        flunk "should not have reached here"
      end
    end
    
    assert_equal 'error', err.message
    assert_equal true, was_in_block
    assert_equal nil, ENV['UNSET_VARIABLE']
  end
  
  def test_with_env_replaces_env_if_specified
    ENV['SET_VARIABLE'] = 'set'
    
    was_in_block = false
    with_env({}, true) do
      was_in_block = true
      assert_equal nil, ENV['SET_VARIABLE']
      assert_equal false, ENV.has_key?('SET_VARIABLE')
    end
    
    assert_equal true, was_in_block
    assert_equal 'set', ENV['SET_VARIABLE']
  end
  
  def test_with_env_returns_block_result
    assert_equal "result", with_env {"result"}
  end
  
  def test_with_env_allows_nil_env
    was_in_block = false
    with_env(nil) do
      was_in_block = true
    end
    
    assert_equal true, was_in_block
  end
  
  #
  # sh_test test
  #
  
  def test_sh_test_documentation
    opts = {
      :cmd_pattern => '% argv_inspect',
      :cmd => 'ruby -e "puts ARGV.inspect"'
    }
  
    sh_test %Q{
% argv_inspect goodnight moon
["goodnight", "moon"]
}, opts
  
    sh_test %Q{
% argv_inspect hello world
["hello", "world"]
}, opts

    sh_test %Q{
ruby -e "puts ENV['SAMPLE']"
value
}, :env => {'SAMPLE' => 'value'}
  end
  
  #
  # sh_test_options test
  #
  
  class ShellTestOptionsExample
    include Tap::Test::ShellTest

    self.sh_test_options = {
      :cmd_pattern => '% sample',
      :cmd => 'command'
    }
  end
  
  def test_sh_test_options
    options = ShellTestOptionsExample.new.sh_test_options
    assert_equal '% sample', options[:cmd_pattern]
    assert_equal 'command', options[:cmd]
  end
end