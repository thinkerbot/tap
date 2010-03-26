require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/test/unit'

class RubyToRubyTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  include TapTestMethods
  
  def default_env
    super.merge('TAPFILE'  => 'tapfile', 'TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
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
