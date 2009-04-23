require File.join(File.dirname(__FILE__), '../doc_test_helper')
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class RunDoc < Test::Unit::TestCase 
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
    /Tap::Dump -- the default dump task/,
    /usage: tap run -- tap\/dump INPUT/,
    /--output OUTPUT              The dump target file/
  end
  
  #
  # error cases
  #
  
  def test_run_without_schema_prints_no_task_specified
    sh_test %Q{
% tap run
no task specified
}

    sh_test %Q{
% tap run -- --+ --++
no task specified
}

    # likely incorrect syntax
    sh_test %Q{
% tap run unknown
no task specified
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
    
    # now with argv syntax
    tempfile do |io, path|
      io << schema.dump(true)
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
  
  #
  # misc
  #
  
  # see http://bahuvrihi.lighthouseapp.com/projects/9908-tap-task-application/tickets/148-exerun-flubs-stopterminate
  def test_run_does_not_suffer_from_stop_bug
    method_root.prepare(:lib, 'echo.rb') do |io|
      io << %q{# ::task
        class Echo < Tap::Task
          def process(input); puts input; end
        end
      }
    end
    
    method_root.prepare(:lib, 'stop.rb') do |io|
      io << %q{# ::task
        class Stop < Tap::Task
          def process; app.stop; end
        end
      }
    end
    
    sh_test %Q{
% tap run -- echo before -- stop --+ echo after
before
}
  end
end