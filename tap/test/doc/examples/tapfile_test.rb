require File.expand_path('../../../tap_test_helper', __FILE__)

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

# Use workflow to create a subclass of Tap::Workflow.  Initialize any tasks
# you need within the block and return the tasks you want to use as the
# entry/exit points for the workflow.

desc "sort the lines of a file"
work :sort_file, :reverse => false do |config|
  n0 = init :cat
  n1 = init :sort, :reverse => config.reverse
  n2 = init :dump

  join n0, n1, :arrayify => true
  join n1, n2, :iterate => true

  [n0, n1]
end

# Use baseclass to define tasks of a specific class.  The singleton class
# can be used to make dependency-based workflows.

baseclass :singleton do
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
      usage: tap tapfile/goodnight *args

      configurations:
              --msg MSG

      options:
              --help                       Print this help
              --config FILE                Specifies a config file
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
    
    sh_match '% tap sort_file tapfile --reverse true',
      /\Awork :sort_file, :reverse => false do |config|\ntask :goodnight, :msg => 'goodnight' do |config, thing|/, 
      :env => default_env.merge('TAPFILE' => 'tapfile')
      
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