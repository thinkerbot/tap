require File.join(File.dirname(__FILE__), '../tap_test_helper')

class QuickstartTest < Test::Unit::TestCase 
  acts_as_script_test

  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/rap")

  def default_command_path
    %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  end
  
  def test_declaration
    script_test(method_root[:output]) do |cmd|
      File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
        file << %q{
# ::desc your basic goodnight moon task
# Says goodnight with a configurable message.
Tap.task(:goodnight, :obj, :message => 'goodnight') do |task, args|
  puts "#{task.message} #{args.obj}"
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
usage: tap run -- goodnight obj

configurations:
        --message MESSAGE

options:
    -h, --help                       Print this help
        --name NAME                  Specify a name
        --use FILE                   Loads inputs from file
}
    end
  end
  
  def test_rake_style_declaration
    script_test(method_root[:output]) do |cmd|
      File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
        file << %q{
# make the declarations available everywhere
extend Tap::Declarations

namespace :example do
  task(:say, :message) do |task, args|
    print(args.message || 'goodnight')
  end

  desc "your basic goodnight moon task"
  task({:goodnight => :say}, :obj) do |task, args|
    puts " #{args.obj}"
  end
end}
      end

      cmd.check "rake-style goodnight moon task", %Q{
% #{cmd} goodnight moon
goodnight moon
% #{cmd} goodnight world --* say hello
hello world
}
    end
  end
  
  def test_hard_and_soft_workflows
    script_test(method_root[:output]) do |cmd|
      File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
        file << %q{
extend Tap::Declarations

# hard coded
a = task(:a) { print 'a' }
b = task(:b) { print 'b' }
c = task(:c) { puts 'c' }
a.sequence(b, c)

# soft coded
task(:x) { print 'x' }
task(:y) { print 'y' }
task(:z) { puts 'z' }}
      end

      cmd.check "workflows", %Q{
% #{cmd} a
abc
% #{cmd} x --: y --: z
xyz
% #{cmd} x -- y -- z --0:1:2
xyz
}
    end
  end
end