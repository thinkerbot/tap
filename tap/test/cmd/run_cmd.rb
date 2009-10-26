require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test'

class RunCmd < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test :cleanup_dirs => [:root]
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  def setup
    super
    @pwd = Dir.pwd
    method_root.chdir(:root, true)
  end
  
  def teardown
    Dir.chdir(@pwd)
    super
  end
  
  #
  # help
  #
  
  def test_run_prints_help
    sh_match "% tap run --help", 
    /usage: tap run/
  end
  
  def test_run_prints_help_from_end
    sh_match "% tap run -- dump a --- --help", 
    /usage: tap run/
  end
  
  def test_run_prints_task_help
    sh_match "% tap run -- dump --help", 
    /Tap::Tasks::Dump -- the default dump task/,
    /usage: tap run -- tap\/tasks\/dump INPUT/,
    /--output OUTPUT              The dump target file/
  end
  
  def test_run_prints_join_help
    sh_match "% tap run -- load --:h.join dump", 
    /Tap::Join -- an unsyncrhonized, multi-way join/,
    /--enq                        Enque output nodes/
  end
  
  def test_run_prints_manifest
    sh_test %Q{
% tap run -T
  dump        # the default dump task
  load        # the default load task
}

    # now with a local task
    method_root.prepare(:lib, 'sample.rb') do |io|
      io << "# ::task a sample task"
    end
    
    sh_test %Q{
% tap run -T
#{File.basename(method_root[:root])}:
  sample      # a sample task
tap:
  dump        # the default dump task
  load        # the default load task
}

    # now with middleware
    method_root.prepare(:lib, 'middle.rb') do |io|
      io << "# ::middleware a sample middleware"
    end
    
    sh_test %Q{
% tap run -t
=== tasks ===
#{File.basename(method_root[:root])}:
  sample      # a sample task
tap:
  dump        # the default dump task
  load        # the default load task
=== joins ===
  join        # an unsyncrhonized, multi-way join
  sync        # a synchronized multi-way join
=== middleware ===
#{File.basename(method_root[:root])}:
  middle      # a sample middleware
tap:
  debugger    # the default debugger
}
  end
  
  #
  # error cases
  #
  
  def test_run_identifies_unknown_schema_files
    sh_test %Q{
% tap run unknown
No such file or directory - unknown
}
  end

  def test_run_prints_error_backtrace_with_debug_flag
    sh_test %Q{
% tap run -- dump 2>&1
wrong number of arguments (0 for 1)
}

    sh_match "% tap run -- dump --- -d 2>&1", 
    /wrong number of arguments \(0 for 1\) \(ArgumentError\)/,
    /from .*:in /
  end

  def test_run_identifies_unresolvable_constants_in_schema
    sh_test %Q{
% tap run -- unknown
unresolvable constant: "unknown"
}

    sh_test %Q{
% tap run --//build 0 unknown
unresolvable constant: "unknown"
}

    sh_test %Q{
% tap run -- load --:.unknown dump
unresolvable constant: "unknown"
}
  end
  
  def test_run_identifies_missing_tasks_in_join
    sh_test %Q{
% tap run --: dump
invalid break: --: (no prior entry)
}

    sh_test %Q{
% tap run -- --: dump
missing join input: 0
}

    sh_test %Q{
% tap run -- load --:
missing join output: 1
}

    sh_test %Q{
% tap run -- load --: -- dump
missing join output: 1
}

    sh_test %Q{
% tap run -- load -- dump --[0][2]
missing join output: 2
}

    sh_test %Q{
% tap run -- load -- dump --[2][1]
missing join input: 2
}
  end
  
  #
  # success cases
  #
  
  def test_run_parses_schema_from_command_line
    sh_test %Q{
% tap run -- load 'goodnight moon' --: dump
goodnight moon
}
    sh_test %Q{
% tap run -- load 'goodnight moon' -- dump --[0][1]
goodnight moon
}
    sh_test %Q{
% tap run -- load --enque 'goodnight moon' --: dump
goodnight moon
}
    sh_test %Q{
% tap run -e -- load --enque 'goodnight moon' --: dump
goodnight moon
}
    sh_test %Q{
% tap run -e -- load --: dump --/0/enq 'goodnight moon'
goodnight moon
}
    sh_test %Q{
% tap run -e -- load -- dump --. join 0 1 --@0 'goodnight moon'
goodnight moon
}
  end
  
  SAMPLE_SCHEMA = [
    {'var' => '0', 'class' => 'tap:load', "config"=>{"use_close"=>false, "file"=>false}},
    {'var' => '1', 'class' => 'tap:dump', "config"=>{"overwrite"=>false}},
    {'class' => 'tap:join', 'inputs' => ['0'], 'outputs' => ['1'], "config"=>{"splat"=>false, "enq"=>false, "iterate"=>false}},
    {'sig' => 'enque', 'args' => ['0', 'goodnight moon']}
  ]
  
  def test_run_loads_schema_from_file
    schema = method_root.prepare(:tmp, 'schema.yml') do |io|
      YAML.dump(SAMPLE_SCHEMA, io)
    end

    sh_test %Q{
% tap run '#{schema}'
goodnight moon
} 
  end
  
  def test_run_may_modify_objects_from_schema_file
    schema = method_root.prepare(:tmp, 'schema.yml') do |io|
      YAML.dump(SAMPLE_SCHEMA, io)
    end

    sh_test %Q{
% tap run '#{schema}' --/0/enq 'hello world'
goodnight moon
hello world
} 
  end
  
  def test_run_prints_schema_on_preview
    path = method_root.prepare(:tmp, 'schema.yml')
    sh_test %Q{
% tap run -p -- load 'goodnight moon' --: dump > '#{path}'
}
    
    schema = YAML.load_file(path)
    assert_equal SAMPLE_SCHEMA, schema
  end
  
  def test_run_auto_enque_preserves_order
    sh_test %Q{
% tap run -- load a --: dump --/0/enq b --- -- --/0/enq c
a
b
c
}
  end
  
  def test_require_enque_prevents_auto_enque
    sh_test %Q{
% tap run --require-enque -- load a -- load b --enque -- dump --[0,1][2] --/0/enq c 2>&1
ignoring args: ["a"]
b
c
}
  end
  
  def test_run_notifies_unused_args
    sh_test %Q{
% tap run -- load a --[0][0] 2>&1
ignoring args: ["a"]
}
  end
  
  def test_auto_enque_does_not_conflict_with_manual_enque
    sh_test %Q{
% tap run -- load a --enque --: dump
a
}
  end
  
  def test_run_using_signals
    sh_test %Q{
% tap run --//build 0 load --//build 1 dump --//build 2 join 0 1 --//enque 0 'goodnight moon'
goodnight moon
}
    sh_test %Q{
% tap run --// 0 load --// 1 dump --// 2 join 0 1 --/0/enq 'goodnight moon'
goodnight moon
}

    sh_test %Q{
% tap run -e -- load --enque 'goodnight moon' -- dump --//build 2 join --/2/join 0 1 
goodnight moon
}

    sh_test %Q{
% tap run --//enque app "/build 0 dump --enque 'goodnight moon'"
goodnight moon
}
  end
  
  def test_run_allows_the_use_of_app_as_a_node
    method_root.prepare(:lib, 'null.rb') do |io|
      io << %q{
        require 'tap/task'

        # ::task
        class Null < Tap::Task
          def joins
          end
        end
      }
    end

    sh_test %Q{
% tap run -- dump --: null --[app][0] --//enque app /info
state: 1 (RUN) queue: 0
}
  end
  
  #
  # middleware
  #
  
  def test_run_allows_the_specification_of_middleware
    method_root.prepare(:lib, 'middleware.rb') do |io|
      io << %q{
        require 'tap/middleware'
        
        # ::middleware
        class Middleware < Tap::Middleware
          def call(node, inputs=[])
            puts node.class
            stack.call(node, inputs)
          end
        end
      }
    end
    
    sh_test %Q{
% tap run -- load 'goodnight moon' --: dump --//use middleware
Tap::Tasks::Load
Tap::Tasks::Dump
goodnight moon
}
  end
end