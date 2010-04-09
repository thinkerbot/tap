require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/test/unit'

class TapfileTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  include TapTestMethods
  
  def test_tapfile_documentation
    method_root.prepare('tapfile') do |io|
      # don't use indents so sort output is correct
      io << %q{
require 'tap/declarations'
extend Tap::Declarations

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
#
# The init and join methods are directly off of Tap::App.  Tapfiles are
# executed in the app binding, so you have access to node, the queue, run,
# etc.

desc "sort the lines of a file"
workflow :sort_file, :reverse => false do |config|
  cat  = init(:cat)
  sort = init(:sort, :reverse => config.reverse)
  dump = init(:dump)

  join(cat, sort, :arrayify => true)
  join(sort, dump, :iterate => true)

  [cat, sort]
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
      Goodnight -- a goodnight task
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
      usage: tap goodnight *args

      configurations:
              --msg MSG

      options:
              --help                       Print this help
              --config FILE                Specifies a config file
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
    
    sh_match '% tap sort_file tapfile --reverse true',
      /\Aworkflow :sort_file, :reverse => false do |config|\ntask :goodnight, :msg => 'goodnight' do |config, thing|/, 
      :env => default_env.merge('TAPFILE' => 'tapfile')
  end
end