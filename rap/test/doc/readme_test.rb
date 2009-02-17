require File.join(File.dirname(__FILE__), '../rap_test_helper')

class ReadmeTest < Test::Unit::TestCase 
  acts_as_script_test

  RAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../../rap/bin/rap")
  LOAD_PATHS = $:.collect {|path| "-I'#{File.expand_path(path)}'"}.uniq.join(' ')
  
  def default_command_path
    %Q{ruby #{LOAD_PATHS} "#{RAP_EXECUTABLE_PATH}"}
  end
  
  def test_readme
    script_test(method_root[:output]) do |cmd|
      File.open(method_root.filepath(:output, 'Rapfile'), 'w') do |file|
        file << %q{
require 'rap/declarations'
include Rap::Declarations

desc "your basic goodnight moon task"

# Says goodnight with a configurable message.
task(:goodnight, :obj, :message => 'goodnight') do |task, args|
  puts "#{task.message} #{args.obj}\n"
end}
      end

      cmd.check "goodnight moon task", %Q{
% #{cmd} goodnight moon
goodnight moon
% #{cmd} goodnight world --message hello
hello world
% #{cmd} goodnight --help
Goodnight -- your basic goodnight moon task
--------------------------------------------------------------------------------
  Says goodnight with a configurable message.
--------------------------------------------------------------------------------
usage: rap goodnight OBJ

configurations:
        --message MESSAGE

options:
        --help                       Print this help
        --name NAME                  Specifies the task name
        --config FILE                Specifies a config file
        --use FILE                   Loads inputs to ARGV
}, false

      File.open(method_root.filepath(:output, 'test.rb'), 'w') do |file|
        file << %q{
load 'Rapfile'
require 'test/unit'
require 'stringio'

class RapfileTest < Test::Unit::TestCase
  def test_the_goodnight_task
    $stdout = StringIO.new

    task = Goodnight.new
    assert_equal 'goodnight', task.message

    task.process('moon')
    assert_equal "goodnight moon\n", $stdout.string
  end
end}
      end

      cmd.check "goodnight moon test", %Q{
% ruby #{LOAD_PATHS} test.rb
Loaded suite test
Started
.
Finished in :...: seconds.

1 tests, 2 assertions, 0 failures, 0 errors
}
    end
  end
end