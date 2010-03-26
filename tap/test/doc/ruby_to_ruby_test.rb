require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/test/unit'

class RubyToRubyTest < Test::Unit::TestCase 
  extend Tap::Test
  TAP_ROOT = File.expand_path("../../..", __FILE__)
  
  acts_as_file_test
  acts_as_shell_test
  
  def setup
    super
    @pwd = Dir.pwd
    method_root.chdir('.', true)
  end
  
  def teardown
    Dir.chdir(@pwd)
    super
  end
  
  def sh_test_options
    {
      :cmd_pattern => "% tap", 
      :cmd => [
        "ruby",
        "-I'#{TAP_ROOT}/../configurable/lib'",
        "-I'#{TAP_ROOT}/../lazydoc/lib'",
        "-I'#{TAP_ROOT}/lib'",
        "'#{TAP_ROOT}/bin/tap'"
      ].join(" "),
      :indents => true,
      :env => default_env,
      :replace_env => false
    }
  end
  
  def default_env
    {
      'HOME' => method_root.path('home'),
      'TAPFILE'  => 'tapfile',
      'TAP_GEMS' => '', 
      'TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks",
      'TAPENV'   => '',
      'TAPRC'    => '',
      'TAP_GEMS' => ''
    }
  end


  def test_ruby_to_ruby
    if RUBY_VERSION < '1.9'
    sh_test %q{
      % tap load string -: dump
      string
    }
    
    sh_test %q{
      % tap load/yaml [array] -: dump
      array
    }
    else
    sh_test %q{
      % tap load string -: dump
      string
    }

    sh_test %q{
      % tap load/yaml [array] -: dump
      ["array"]
    }
    end
    
    tapfile = method_root.prepare('tapfile') do |io|
      io << %q{
        require 'tap/declarations'
        Tap.task(:one) {|config, a, b, c| "#{a}\n#{b}\n#{c}" }
        Tap.task(:two) {|config, input| puts input }
      }
    end
    
    if RUBY_VERSION >= '1.9'
    sh_test %q{
      % tap one 1 2 3 -: two
      1
      2
      3
    }
    else
    sh_test %q{
      % tap one 1 2 3 -: two
      1
    }

    sh_test %q{
      % tap one 1 2 3 -:a two
      1
      2
      3
    }
    end
  end
end
