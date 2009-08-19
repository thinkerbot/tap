require File.join(File.dirname(__FILE__), '../doc_test_helper')
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class RunCmd < Test::Unit::TestCase 
  include Doctest
  include MethodRoot
  
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
  
  def test_run_prints_spec_help
    sh_match "% tap run -- --. middleware debugger --help", 
    /Tap::Middlewares::Debugger/,
    /--help                       Print this help/
  end
  
  def test_run_prints_manifest
    expected = %Q{
  dump        # the default dump task
  load        # the default load task
}
    assert_equal expected, "\n" + sh("#{CMD} run -T")
    
    # now with a local task
    method_root.prepare(:lib, 'sample.rb') do |io|
      io << "# ::task a sample task"
    end
    
    expected = %Q{
#{File.basename(method_root[:root])}:
  sample      # a sample task
tap:
  dump        # the default dump task
  load        # the default load task
}
    assert_equal expected, "\n" + sh("#{CMD} run -T")

    # now with middleware
    method_root.prepare(:lib, 'middle.rb') do |io|
      io << "# ::middleware a sample middleware"
    end
    
    expected = %Q{
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
    assert_equal expected, "\n" + sh("#{CMD} run -t")
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

  def test_run_identifies_unresolvable_tasks_in_schema
    sh_test %Q{
% tap run -- unknown
unresolvable task: "unknown"
}

    sh_test %Q{
% tap run -- unknown 1 2 3
unresolvable task: "unknown"
}

    sh_test %Q{
% tap run -- load -- unknown -- dump
unresolvable task: "unknown"
}
  end
  
  def test_run_identifies_missing_tasks_in_schema
    sh_test %Q{
% tap run -- load --: 
unresolvable task: nil
}
    
    sh_test %Q{
% tap run -- load -- dump  --[0][2]
missing join output: 2
}

    sh_test %Q{
% tap run -- --: dump
missing join input: 0
}

    sh_test %Q{
% tap run -- --: dump -- load
missing join input: 0
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
  end
  
  SAMPLE_SCHEMA = [
    {'set' => '0', 'type' => 'task', 'class' => 'tap:load', "config"=>{"use_close"=>false, "file"=>false}},
    {'set' => '1', 'type' => 'task', 'class' => 'tap:dump', "config"=>{"overwrite"=>false}},
    {'type' => 'join', 'class' => 'tap:join', 'inputs' => ['0'], 'outputs' => ['1'], "config"=>{"splat"=>false, "enq"=>false, "iterate"=>false}},
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
  
  def test_run_prints_schema_on_preview
    path = method_root.prepare(:tmp, 'schema.yml')
    sh %Q{#{CMD} run -p -- load 'goodnight moon' --: dump > '#{path}'}
    
    schema = YAML.load_file(path)
    assert_equal SAMPLE_SCHEMA, schema
  end
  
  def test_run_auto_enque_preserves_order
    sh_test %Q{
% tap run -- load a --: dump --@ 0 b --- -- --@ 0 c
a
b
c
}
  end
  
  def test_require_enque_prevents_auto_enque
    sh_test %Q{
% tap run --require-enque -- load a -- load b --enque -- dump --[0,1][2] --@ 0 c 2>&1
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
% tap run -- load 'goodnight moon' --: dump --. middleware middleware
Tap::Tasks::Load
Tap::Tasks::Dump
goodnight moon
}
  end
end