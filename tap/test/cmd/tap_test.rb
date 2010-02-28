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
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  def setup
    super
    @pwd = Dir.pwd
    @current_env = set_env({
      'HOME' => method_root.path('home')
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

  def test_tap_parses_and_runs_workflow
    sh_test %Q{
    % tap --/env/auto '#{TAP_ROOT}/../tap-tasks' -- load 'goodnight moon' -: dump
    goodnight moon
    }
  end
  
  def test_tap_scans_pwd_lib_for_constants
    method_root.prepare('pwd/lib/a.rb') do |io|
      io.puts 'require "tap/task"'
      io.puts '# ::task'
      io.puts 'class A < Tap::Task; def process; puts "a"; end; end'
    end
    
    method_root.prepare('pwd/lib/b/c.rb') do |io|
      io.puts 'require "tap/task"'
      io.puts '# ::task'
      io.puts 'module B; class C < Tap::Task; def process; puts "c"; end; end; end'
    end
    
    sh_test %Q{
    % tap a -- c
    a
    c
    }
  end
  
  def test_tap_scans_directories_specified_in_TAP_ENV_DIRS_for_constants
    method_root.prepare('a/lib/a.rb') do |io|
      io.puts 'require "tap/task"'
      io.puts '# ::task'
      io.puts 'class A < Tap::Task; def process; puts "a"; end; end'
    end
    
    method_root.prepare('pwd/alt/lib/b/c.rb') do |io|
      io.puts 'require "tap/task"'
      io.puts '# ::task'
      io.puts 'module B; class C < Tap::Task; def process; puts "c"; end; end; end'
    end
    
    with_env('TAP_ENV_DIRS' => '../a:alt') do
      sh_test %Q{
      % tap a -- c
      a
      c
      }
    end
  end
  
  def test_tap_executes_tapfiles_in_app_context
    tapfile = method_root.prepare('tapfile') do |io|
      io.puts "env/auto '#{TAP_ROOT}/../tap-tasks'"
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
      io.puts "  env/auto '#{TAP_ROOT}/../tap-tasks'"
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
    % tap --/env/auto '#{TAP_ROOT}/../tap-tasks' --- '#{tapfile}'
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
  
  def test_tap_load_taprc_file_in_home_directory
    method_root.prepare('home/.taprc') do |io|
      io.puts "env/auto '#{TAP_ROOT}/../tap-tasks'"
      io.puts "set 0 load"
      io.puts "set 1 dump"
      io.puts "build join 0 1"
      io.puts "enq 0 'goodnight moon'"
    end
    
    sh_test %Q{
    % tap load 'hello world' -: dump
    goodnight moon
    hello world
    }
  end
  
  def test_TAPRC_variable_can_be_used_to_specify_the_path_to_taprc_files
    a = method_root.prepare('home/a') do |io|
      io.puts "env/auto '#{TAP_ROOT}/../tap-tasks'"
    end
    
    b = method_root.prepare('pwd/path/to/b') do |io|
      io.puts "set 0 load"
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
