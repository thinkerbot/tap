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
  # set_env test
  #
  
  def test_set_env_sets_the_env_and_returns_the_current_env
    current_env = {}
    begin
      ENV.each_pair do |key, value|
        current_env[key] = value
      end
      
      assert_equal nil, ENV['NEW_ENV_VAR']
      assert_equal nil, current_env['NEW_ENV_VAR']
      
      assert_equal current_env, set_env('NEW_ENV_VAR' => 'value')
      assert_equal 'value', ENV['NEW_ENV_VAR']
    ensure
      ENV.clear
      current_env.each_pair do |key, value|
        ENV[key] = value
      end
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
% argv_inspect hello world
["hello", "world"]
}, opts

sh_test %Q{
    % argv_inspect hello world
    ["hello", "world"]
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
  
  def test_sh_test_strips_indents
    sh_test %Q{
    echo goodnight
    goodnight
    }
    
    sh_test %Q{ \t   \r
    echo goodnight
    goodnight
    }
    
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
  
  def test_sh_test_does_not_strip_indents_unless_specified
    sh_test %Q{
    ruby -e 'print "    \\t\\n      "'
    \t
      }, :indents => false
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
  
  #
  # assert_output_equal test
  #
  
  def test_assert_output_equal_documentation
    assert_output_equal %q{
line one
line two
}, "line one\nline two\n"
    
    assert_output_equal %q{
  line one
  line two
}, "line one\nline two\n"
    
    assert_output_equal %q{
    line one
    line two
    }, "line one\nline two\n"
  end
  
  def test_assert_output_equal
    assert_output_equal %q{
    line one
      line two
    }, "line one\n  line two\n"
    
    assert_output_equal %q{
    line one
      line two}, "line one\n  line two"
    
    assert_output_equal %Q{  \t   \r
    line one
    line two
    }, "line one\nline two\n"
      
    assert_output_equal %q{
    
    
    }, "\n\n"
      
    assert_output_equal %q{
    
    }, "\n"
    
    assert_output_equal %Q{  \t   \r
    
    }, "\n"
    
    assert_output_equal %q{
    }, ""
    
    assert_output_equal %q{}, ""
    assert_output_equal %q{line one
line two
}, "line one\nline two\n"
  end
  
  #
  # assert_output_equal! test
  #
  
  def test_assert_output_equal_bang_does_not_strip_indentation
    assert_output_equal! %q{
    }, "\n    "
  end
  
  #
  # assert_alike test
  #
  
  def test_assert_alike_documentation
    assert_alike %q{
the time is: :...:
now!
}, "the time is: #{Time.now}\nnow!\n"

    assert_alike %q{
  the time is: :...:
  now!
}, "the time is: #{Time.now}\nnow!\n"

    assert_alike %q{
    the time is: :...:
    now!
    }, "the time is: #{Time.now}\nnow!\n"
  end
  
  def test_assert_alike
    assert_alike(/abc/, "...abc...")
  end
  
  def test_assert_alike_regexp_escapes_strings
    assert_alike "a:...:c", "...alot of random stuff toc..."
  end
end