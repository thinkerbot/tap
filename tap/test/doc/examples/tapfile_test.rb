require File.expand_path('../../../test_helper', __FILE__)

class TapfileTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  include TapTestMethods
  
  def test_tapfile_documentation
    method_root.prepare('tapfile') do |io|
      # don't use indents so sort output is correct
      io << %q{
# A task declaration looks like this. The declaration creates a subclass of
# Tap::Task, literally this:
#
#   class Goodnight < Tap::Task
#     config :msg, 'goodnight'
#     def process(thing)
#       "#{msg} #{thing}!"
#     end
#   end
#
# The 'config' passed to the block is actually the task instance but it's
# useful to think of it as a source of configs.  Note these comments are
# meaningful, if present they become the task help.

desc "a goodnight task"
task :goodnight, :msg => 'goodnight' do |config, thing|
  "#{config.msg} #{thing}!"
end

# Use namespace to set tasks within a module.
namespace :example do
  desc "concat files"
  task :cat do |config, *paths|
    paths.collect {|path| File.read(path) }.join
  end

  desc "sort a string by line"
  task :sort, :reverse => false do |config, str|
    lines = str.split("\n").sort
    config.reverse ? lines.reverse : lines
  end
end

# Use workflow to create a subclass of Tap::Workflow.  Access any tasks you
# define in the workflow using node and return the tasks you want to use as
# the entry/exit points for the workflow.

desc "sort the lines of a file"
work :sort_file, %q{
  -   cat
  -:a sort
  -:i dump
},{
  :reverse => false
} do |config|
  n0 = node(0)    # cat
  n1 = node(1)    # sort
  n1.reverse = config.reverse 
  [n0, n1]
end


# Tasks defined in a singleton block will only execute once (given a set
# of inputs) and can be used to make dependency-based workflows.

singleton do
  task(:a)             { puts 'a' }
  task(:b => :a)       { puts 'b' }
  task(:c => [:b, :a]) { puts 'c' }
end
}
    end

    sh_test %q{
      % tap goodnight moon -: dump
      goodnight moon!
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
    
    sh_test %q{
      % tap goodnight world --msg hello -: dump
      hello world!
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
    
    sh_test %q{
      % tap goodnight --help
      Tapfile::Goodnight -- a goodnight task
      --------------------------------------------------------------------------------
        A task declaration looks like this. The declaration creates a subclass of
        Tap::Task, literally this:
        
          class Goodnight < Tap::Task
            config :msg, 'goodnight'
            def process(thing)
              "#{msg} #{thing}!"
            end
          end
        
        The 'config' passed to the block is actually the task instance but it's
        useful to think of it as a source of configs.  Note these comments are
        meaningful, if present they become the task help.
      --------------------------------------------------------------------------------
      usage: tap tapfile/goodnight arg

      configurations:
              --msg MSG

      options:
              --help                       Print this help
              --config FILE                Specifies a config file
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
    
    sh_match '% tap sort_file tapfile --reverse true',
      /\Awork :sort_file, :reverse => false do |config|\ntask :goodnight, :msg => 'goodnight' do |config, thing|/, 
      :env => default_env.merge('TAPFILE' => 'tapfile')
    
    if RUBY_VERSION > '1.8.6'
      sh_test %q{
        % tap c
        a
        b
        c
      }, :env => default_env.merge('TAPFILE' => 'tapfile')
    
      sh_test %q{
        % tap b -- a
        a
        b
      }, :env => default_env.merge('TAPFILE' => 'tapfile')
    end
  end
  
  def test_first_node_is_input_node_when_undeclared
    method_root.prepare('tapfile') do |io|
      io << %q{
        work :example, %q{
          -  load
          -: dump
        }
      }
    end
    
    sh_test %q{
      % tap example pass
      pass
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
  end
end