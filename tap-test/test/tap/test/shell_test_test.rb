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
  
  def test_sh_test_replaces_percent_and_redirects_output_by_default 
    sh_test %Q{
ruby -e "STDERR.puts 'on stderr'; STDOUT.puts 'on stdout'"
on stdout
}

    sh_test %Q{
% ruby -e "STDERR.puts 'on stderr'; STDOUT.puts 'on stdout'"
on stderr
on stdout
}
  end
    
  def test_sh_test_correctly_matches_no_output
    sh_test %Q{
ruby -e ""
}

    sh_test %Q{ruby -e ""}
  end
  
  def test_sh_test_correctly_matches_whitespace_output
    sh_test %Q{
ruby -e 'print "\\t\\n  "'
\t
  }
    sh_test %Q{
echo

}
    sh_test %Q{echo

}
  end
  
  def test_sh_test_fails_on_mismatch
    err = assert_raises(Test::Unit::AssertionFailedError) { sh_test %Q{ruby -e ""\nflunk} }
    assert_equal %Q{
ruby -e "".
<"flunk"> expected but was
<"">.}, "\n" + err.message

    err = assert_raises(Test::Unit::AssertionFailedError) { sh_test %Q{echo pass\nflunk} }
    assert_equal %Q{
echo pass.
<"flunk"> expected but was
<"pass\\n">.}, "\n" + err.message
  end
  
  #
  # sh_match test
  #

  def test_sh_match_matches_regexps_to_output
    opts = {
      :cmd_pattern => '% argv_inspect',
      :cmd => 'ruby -e "puts ARGV.inspect"'
    }

    sh_match "% argv_inspect goodnight moon",
    /goodnight/,
    /mo+n/,
    opts

    sh_match "echo goodnight moon",
    /goodnight/,
    /mo+n/
  end
  
  def test_sh_match_fails_on_mismatch
    err = assert_raises(Test::Unit::AssertionFailedError) do
      sh_match "ruby -e ''", /output/
    end
    
    assert_equal %Q{
ruby -e ''.
<""> expected to be =~
</output/>.}, "\n" + err.message

    err = assert_raises(Test::Unit::AssertionFailedError) do
      sh_match "echo pass", /pas+/, /fail/
    end
    
    assert_equal %Q{
echo pass.
<"pass\\n"> expected to be =~
</fail/>.}, "\n" + err.message
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