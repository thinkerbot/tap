require File.expand_path('../../tap_test_helper', __FILE__)

class WorkflowSyntaxTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  include TapTestMethods
  
if RUBY_VERSION < '1.9'
  def test_workflow_syntax
    sh_test %q{
      % tap dump 'goodnight moon'
      goodnight moon
    }
    
    sh_match "% tap dump --help",
      /Tap::Tasks::Dump -- the default dump task/
    
    sh_test %q{
      % tap dump a - dump b -- dump c
      ignoring args: ["b"]
      a
      c
    }
    
    sh_test %q{
      % tap - dump a -- dump b - dump c
      ignoring args: ["a"]
      ignoring args: ["c"]
      b
    }
    
    sh_test %q{
      % tap load 'joined by a join' - dump - join 0 1
      joined by a join
    }
    
    sh_test %q{
      % tap - dump -/0/enq 'enqued by a signal'
      enqued by a signal
    }
    
    # % tap load
    # % tap tap/tasks/load
    # % tap /tap/tasks/load
    # % tap Tap::Tasks::Load
    # % tap tap:load
    # % tap /tap/tasks:tasks/load
    # % tap /tap/tasks/load:
    
    sh_test %q{
      % tap dump begin -. -- - -- --- -: -/ --/ .- end
      begin-------:-/--/end
    }

    sh_test %q{
      % tap load 'goodnight moon' -: dump
      goodnight moon
    }
    
    sh_test %q{
      % tap load 'goodnight moon' - dump - join 0 1
      goodnight moon
    }
    
    sh_test %q{
      % tap load 'goodnight moon' - dump - dump - join 0 1,2
      goodnight moon
      goodnight moon
    }
    
    sh_test %q{
      % tap load goodnight -- load moon - dump - join 0,1 2
      goodnight
      moon
    }
    
    sh_test %q{
      % tap load a -- load b -- load c - dump - gate 0,1,2 3 --limit 2
      ab
      c
    }
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" - dump - join 0 1
      123
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" - dump - join 0 1 --iterate
      1
      2
      3
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" - dump - dump - join 0 1 --iterate - gate 1 2
      1
      2
      3
      123
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" -:i dump -:.gate dump
      1
      2
      3
      123
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap -/set 0 load -/set 1 dump -/bld join 0 1 -/enq 0 'goodnight moon'
      goodnight moon
    }
    
    # sh_test %q{
    #   % tap prompt
    #   /set 0 load
    #   /set 1 dump
    #   /bld join 0 1
    #   /enq 0 'goodnight moon'
    #   /run
    #   goodnight moon

    taprc = method_root.prepare('tapfile') do |io|
      io << %q{
      set 0 load
      set 1 dump
      bld join 0 1
      enq 0 'goodnight moon'
      }
    end
    
    sh_test %Q{
      % tap --- '#{taprc}'
      goodnight moon
    }
    
    sh_test %Q{
      % tap --- '#{taprc}' '#{taprc}' '#{taprc}'
      goodnight moon
      goodnight moon
      goodnight moon
    }
    
    sh_test %q{
      % tap - dump -/0/exe 'goodnight moon'
      goodnight moon
    }
    
    sh_test %q{
      % tap -- dump a -/0/exe b --/0/exe c
      c
      a
      b
    }
  end
else
  def test_workflow_syntax
    sh_test %q{
      % tap dump 'goodnight moon'
      ["goodnight moon"]
    }
    
    sh_match "% tap dump --help",
      /Tap::Tasks::Dump -- the default dump task/
    
    sh_test %q{
      % tap dump a - dump b -- dump c
      ignoring args: ["b"]
      ["a"]
      ["c"]
    }
    
    sh_test %q{
      % tap - dump a -- dump b - dump c
      ignoring args: ["a"]
      ignoring args: ["c"]
      ["b"]
    }
    
    sh_test %q{
      % tap - dump -/0/enq 'enqued by a signal'
      ["enqued by a signal"]
    }
    
    # % tap load
    # % tap tap/tasks/load
    # % tap /tap/tasks/load
    # % tap Tap::Tasks::Load
    # % tap tap:load
    # % tap /tap/tasks:tasks/load
    # % tap /tap/tasks/load:
    
    sh_test %q{
      % tap dump begin -. -- - -- --- -: -/ --/ .- end
      ["begin", "-", "--", "---", "-:", "-/", "--/", "end"]
    }

    sh_test %q{
      % tap load 'goodnight moon' -: dump
      goodnight moon
    }
    
    sh_test %q{
      % tap load 'goodnight moon' - dump - join 0 1
      goodnight moon
    }
    
    sh_test %q{
      % tap load 'goodnight moon' - dump - dump - join 0 1,2
      goodnight moon
      goodnight moon
    }
    
    sh_test %q{
      % tap load goodnight -- load moon - dump - join 0,1 2
      goodnight
      moon
    }
    
    sh_test %q{
      % tap load a -- load b -- load c - dump - gate 0,1,2 3 --limit 2
      ["a", "b"]
      ["c"]
    }
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" - dump - join 0 1
      [1, 2, 3]
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" - dump - join 0 1 --iterate
      1
      2
      3
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" - dump - dump - join 0 1 --iterate - gate 1 2
      1
      2
      3
      [1, 2, 3]
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap load/yaml "[1, 2, 3]" -:i dump -:.gate dump
      1
      2
      3
      [1, 2, 3]
    }, :env => default_env.merge('TAP_PATH' => "#{TAP_ROOT}:#{TAP_ROOT}/../tap-tasks")
    
    sh_test %q{
      % tap -/set 0 load -/set 1 dump -/bld join 0 1 -/enq 0 'goodnight moon'
      goodnight moon
    }
    
    # sh_test %q{
    #   % tap prompt
    #   /set 0 load
    #   /set 1 dump
    #   /bld join 0 1
    #   /enq 0 'goodnight moon'
    #   /run
    #   goodnight moon

    taprc = method_root.prepare('tapfile') do |io|
      io << %q{
      set 0 load
      set 1 dump
      bld join 0 1
      enq 0 'goodnight moon'
      }
    end
    
    sh_test %Q{
      % tap --- '#{taprc}'
      goodnight moon
    }
    
    sh_test %Q{
      % tap --- '#{taprc}' '#{taprc}' '#{taprc}'
      goodnight moon
      goodnight moon
      goodnight moon
    }
    
    sh_test %q{
      % tap - dump -/0/exe 'goodnight moon'
      ["goodnight moon"]
    }
    
    sh_test %q{
      % tap -- dump a -/0/exe b --/0/exe c
      ["c"]
      ["a"]
      ["b"]
    }
  end
end
end