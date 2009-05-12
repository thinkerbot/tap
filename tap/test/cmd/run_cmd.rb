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
  
  def test_run_prints_task_help
    sh_match "% tap run -- dump --help", 
    /Tap::Tasks::Dump -- the default dump task/,
    /usage: tap run -- tap\/tasks\/dump INPUT/,
    /--output OUTPUT              The dump target file/
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
=== middleware ===
  middle      # a sample middleware
}
    assert_equal expected, "\n" + sh("#{CMD} run -T")
  end
  
  #
  # error cases
  #
  
  def test_run_without_schema_prints_no_task_specified
    sh_test %Q{
% tap run
no nodes specified
}

    sh_test %Q{
% tap run -- -- --
no nodes specified
}

    # likely incorrect syntax
    sh_test %Q{
% tap run unknown
no nodes specified
(did you mean 'tap run -- unknown'?)
}
  end

  def test_run_identifies_unknown_schema
    sh_test %Q{
% tap run -s unknown
No such schema file - unknown
}
  end
    
  def test_run_identifies_unknown_tasks_in_schema
    sh_test %Q{
% tap run -- unknown
unknown task: unknown
}

    sh_test %Q{
% tap run -- load -- unknown -- dump
unknown task: unknown
}
  end
  
  def test_run_identifies_missing_tasks_in_schema
    sh_test %Q{
% tap run -- load --: 
missing join output: 1
}
    
    sh_test %Q{
% tap run -- load -- dump  --[0][2]
missing join output: 2
}

    sh_test %Q{
% tap run -- --: dump
missing join input: -1
}

    # just to make sure -1 won't refer to the last task...
    sh_test %Q{
% tap run -- --: dump -- load
missing join input: -1
}

    sh_test %Q{
% tap run -- load -- dump --[2][1]
missing join input: 2
}
  end

  def test_multiple_errors_are_collected
    sh_test %Q{
% tap run -- a '--: c' b --[3][4]
5 build errors
unknown task: a
unknown task: b
unknown join: c
missing join input: 3
missing join output: 4
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
  
  def test_run_loads_and_runs_schema
    schema = Tap::Schema.parse("load 'goodnight moon' --: dump")
    tempfile do |io, path|
      io << schema.dump
      io.flush
      
      sh_test %Q{
% tap run -s#{path}
goodnight moon
}
    end
  end
  
  def test_run_loads_and_runs_multiple_schema
    tempfile do |a, path_a|
      a << Tap::Schema.parse("load 'goodnight moon' --: dump").dump
      a.flush
      
      tempfile do |b, path_b|
        b << Tap::Schema.parse("load 'hello world' --: dump").dump
        b.flush

        sh_test %Q{
% tap run -s#{path_a} -s#{path_b} -s#{path_a}
goodnight moon
hello world
goodnight moon
}
      end
    end
  end
  
  CANONICAL_SCHEMA = %q{
tasks:
  0: {id: load}
  1: [dump]
joins:
  0: [[0], [1], {id: join}]
queue:
  0: [0, [goodnight moon]]
---
tasks:
- {id: load}
- [dump]
joins:
- [[0], [1], {id: join}]
queue:
- [0, [goodnight moon]]
---
tasks:
- id: load
  args: [goodnight moon]
- [dump]
joins:
- [[0], [1], {id: join}]
queue:
- 0
---
tasks:
- id: load
- [dump]
joins:
  0:
    0: [0]
    1: [1]
    2: [join]
queue:
  0: 
    0: 0
    1: [goodnight moon]
---
tasks:
- [load, goodnight moon]
- [dump]
joins:
- [[0], [1]]
queue:
- 0
}

  def test_run_with_canonical_schema
    CANONICAL_SCHEMA.split("---").each do |schema|
      tempfile do |io, path|
        io << schema
        io.flush
        
        sh_test %Q{
% tap run -s#{path}
goodnight moon
}
      end
    end
  end
  
  #
  # middleware
  #
  
  def test_allows_the_specification_of_middleware
    method_root.prepare(:lib, 'middleware.rb') do |io|
      io << %q{# ::middleware
        class Middleware
          attr_reader :stack
          def initialize(stack)
            @stack = stack
          end
          def call(node, inputs=[])
            puts node.class
            stack.call(node, inputs)
          end
        end
      }
    end
    
    sh_test %Q{
% tap run -m middleware -- load 'goodnight moon' --: dump
Tap::Tasks::Load
Tap::Tasks::Dump
goodnight moon
}
  end
  
  #
  # misc
  #
  
#   # see http://bahuvrihi.lighthouseapp.com/projects/9908-tap-task-application/tickets/148-exerun-flubs-stopterminate
#   def test_run_does_not_suffer_from_stop_bug
#     method_root.prepare(:lib, 'echo.rb') do |io|
#       io << %q{# ::task
#         class Echo < Tap::Task
#           def process(input); puts input; end
#         end
#       }
#     end
#     
#     method_root.prepare(:lib, 'stop.rb') do |io|
#       io << %q{# ::task
#         class Stop < Tap::Task
#           def process; app.stop; end
#         end
#       }
#     end
#     
#     sh_test %Q{
# % tap run -- echo before -- stop --+ echo after
# before
# }
#   end
end