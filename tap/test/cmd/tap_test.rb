require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test'
require 'tap/version'

class TapCmd < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "-I'#{TAP_ROOT}/lib'",
    "'#{TAP_ROOT}/bin/tap' --/env/auto '#{TAP_ROOT}/../tap-tasks' -- "
  ].join(" ")
  
  def setup
    super
    @pwd = Dir.pwd
    method_root.chdir('.', true)
  end
  
  def teardown
    Dir.chdir(@pwd)
    super
  end
  
  def test_tap_returns_nothing_with_no_input
    sh_test %q{
    % tap
    }
  end
  
  def test_tap_parses_and_runs_workflow
    sh_test %q{
    % tap load 'goodnight moon' -: dump
    goodnight moon
    }
  end
  
  def test_tap_parses_signals
    sh_test %q{
    % tap -/set 0 load -/set 1 dump -/build join 0 1 -/enq 0 'goodnight moon'
    goodnight moon
    }
  end
  
  def test_tap_executes_tapfile
    tapfile = method_root.prepare('file.txt') do |io|
      io.puts "set 0 load"
      io.puts "set 1 dump"
      io.puts "build join 0 1"
      io.puts "enq 0 'goodnight moon'"
    end
    
    sh_test %Q{
    % tap --- '#{tapfile}'
    goodnight moon
    }
  end
  
  def test_tapfiles_may_contain_newlines_empty_lines_and_indentation
    tapfile = method_root.prepare('file.txt') do |io|
      io << %q{
  set 0 dump

enq 0 'goodnight\
moon'
}
    end
    
    sh_test %Q{
    % tap --- '#{tapfile}'
    goodnight
    moon
    }
  end

  def test_tapfiles_may_contain_comments
    tapfile = method_root.prepare('file.txt') do |io|
      io << %q{
      # comment
      set 0 dump              # tail comment
      enq 0 \#notacomment
      enq 0 not#acomment
      enq 0 notacomment#
      enq 0 '# not a comment'
      enq 0 \#notacomment     # each
      enq 0 not#acomment      # with
      enq 0 notacomment#      # tail
      enq 0 '# not a comment' # comment
      }
    end

    sh_test %Q{
    % tap --- '#{tapfile}'
    #notacomment
    not#acomment
    notacomment#
    # not a comment
    #notacomment
    not#acomment
    notacomment#
    # not a comment
    }
  end
end
