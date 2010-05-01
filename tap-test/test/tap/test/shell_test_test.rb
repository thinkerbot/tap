require File.expand_path('../../../tap_test_helper.rb', __FILE__) 
require 'tap/test/shell_test'

class ShellTestSample < Test::Unit::TestCase
  include Tap::Test::ShellTest
  
  def sh_test_options
    {
      :cmd_pattern => '% inspect_argv',
      :cmd => 'ruby -e "puts ARGV.inspect"'
    }
  end
  
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
  
  TestUnitErrorClass = Object.const_defined?(:MiniTest) ? MiniTest::Assertion : Test::Unit::AssertionFailedError
  
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
      assert_equal true, quiet?
    end
  end
  
  def test_verbose_wins_over_quiet
    with_env 'VERBOSE' => 'true', 'QUIET' => 'true' do
      assert_equal true, verbose?
      assert_equal false, quiet?
    end
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
    assert_raises(TestUnitErrorClass) { sh_test %Q{ruby -e ""\nflunk} }
    assert_raises(TestUnitErrorClass) { sh_test %Q{echo pass\nflunk} }
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
    assert_raises(TestUnitErrorClass) do
      sh_match "ruby -e ''", /output/
    end
    
    assert_raises(TestUnitErrorClass) do
      sh_match "echo pass", /pas+/, /fail/
    end
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