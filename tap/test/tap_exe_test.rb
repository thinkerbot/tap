require File.expand_path('../tap_test_helper', __FILE__)
require 'tap/test'
require 'tap/version'

class TapExeTest < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test
  acts_as_shell_test SH_TEST_OPTIONS
  
  def setup
    super
    @pwd = Dir.pwd
    @current_env = set_env({
      'HOME' => method_root.path('home'),
      'TAP_GEMS' => '',
      'TAP_PATH' => TAP_ROOT
    }, true)
    method_root.chdir('pwd', true)
  end
  
  def teardown
    set_env(@current_env, true)
    Dir.chdir(@pwd)
    super
  end
  
  def test_tap_returns_nothing_with_no_input
    sh_test %q{
    % tap
    }
  end
  
  def test_tap_with_a_help_option_returns_help
    sh_match' % tap --help',
      /usage: tap/
      /version.*--http:/
  end
  
  def test_tap_parses_and_runs_workflow
    sh_test %Q{
    % tap -- load 'goodnight moon' -: dump
    goodnight moon
    }
  end
  
  def test_tap_squelches_unhandled_errors
    sh_test %q{
    % tap a 2>&1
    unresolvable constant: "a" (RuntimeError)
    }
  end
  
  def test_TAP_DEBUG_variable_turns_on_debugging
    with_env('TAP_DEBUG' => 'true') do
      sh_match' % tap a 2>&1',
        /unresolvable constant.*RuntimeError/
    end
  end
  
  def test_tap_executes_tapfiles_in_app_context
    tapfile = method_root.prepare('tapfile') do |io|
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
    tapfile = method_root.prepare('tapfile') do |io|
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
    tapfile = method_root.prepare('tapfile') do |io|
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
  
  def test_TAP_PATH_variable_specifies_auto_scan_dirs
    method_root.prepare('alt/lib/a.rb') do |io|
      io.puts 'require "tap/task"'
      io.puts '# ::task'
      io.puts 'class A < Tap::Task; def process; puts "A"; end; end'
    end
    
    sh_test %Q{
    % tap a 2>&1
    unresolvable constant: "a" (RuntimeError)
    }
    
    with_env('TAP_PATH' => '../alt') do
      sh_test %Q{
      % tap a
      A
      }
    end
  end

  def test_TAPENV_specifies_tapenv_files_run_in_env_context
    method_root.prepare('alt/lib/a.rb') do |io|
      io.puts 'require "tap/task"'
      io.puts '# ::task'
      io.puts 'class A < Tap::Task; def process; puts "A"; end; end'
    end
    
    method_root.prepare('pwd/altenv') do |io|
      io.puts 'auto ../alt'
    end
    
    sh_test %Q{
    % tap a 2>&1
    unresolvable constant: "a" (RuntimeError)
    }
    
    with_env('TAPENV' => 'altenv') do
      sh_test %Q{
      % tap a
      A
      }
    end
  end
  
  def test_TAPRC_variable_specifies_taprc_files_run_in_app_context
    a = method_root.prepare('home/a') do |io|
      io.puts "set 0 load"
    end
    
    b = method_root.prepare('pwd/path/to/b') do |io|
      io.puts "set 1 dump"
      io.puts "build join 0 1"
      io.puts "enq 0 'goodnight moon'"
    end
    
    with_env('TAPRC' => '~/a:./path/to/b') do
      sh_test %Q{
      % tap load 'hello world' -: dump
      goodnight moon
      hello world
      }
    end
  end
end
