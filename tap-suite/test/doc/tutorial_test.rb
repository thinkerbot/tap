require File.join(File.dirname(__FILE__), '../tap_test_helper')

class TutorialTest < Test::Unit::TestCase 
  acts_as_script_test

  RAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../../rap/bin/rap")
  LOAD_PATHS = $:.collect {|path| "-I'#{File.expand_path(path)}'"}.uniq.join(' ')
  
  def default_command_path
    %Q{ruby #{LOAD_PATHS} "#{RAP_EXECUTABLE_PATH}"}
  end
  
  def test_declaration
    script_test(method_root[:output]) do |cmd|
      File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
        file << %q{
# ::desc your basic goodnight moon task
# Says goodnight with a configurable message.
Rap.task(:goodnight, :obj, :message => 'goodnight') do |task, args|
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
usage: rap goodnight OBJ

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
include Rap::Declarations

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
  
  # Goodnight::manifest your basic goodnight moon task
  # Says goodnight with a configurable message.
  class Goodnight < Tap::Task
    config :message, 'goodnight'

    def process(obj)
      "#{message} #{obj}"
    end
  end
  
  def test_goodnight_class_definition
    goodnight = Goodnight.new
    assert_equal 'goodnight', goodnight.message
    assert_equal 'goodnight moon', goodnight.process('moon')

    hello = Goodnight.new(:message => 'hello')
    assert_equal 'hello', hello.message
    assert_equal 'hello world', hello.process('world')
  end
  
  def test_goodnight_with_validations
    script_test(method_root[:output]) do |cmd|
      FileUtils.mkdir(method_root.filepath(:output, 'lib'))
      File.open(method_root.filepath(:output, 'lib/goodnight.rb'), 'w') do |file|
        file << %q{
# Goodnight::manifest a fancy goodnight moon task
# Says goodnight with a configurable message.
class Goodnight < Tap::Task
  config :message, 'goodnight'           # a goodnight message
  config :reverse, false, &c.switch      # reverses the message
  config :n, 1, &c.integer               # repeats message n times

  def process(*objects)
    print "#{reverse == true ? message.reverse : message} " * n
    puts objects.join(', ')
    puts
  end
end
}
      end
      
      cmd.check "goodnight with validations", %Q{
% #{cmd} goodnight moon
goodnight moon

% #{cmd} goodnight moon mittens "little toy boat"
goodnight moon, mittens, little toy boat

% #{cmd} goodnight world --message hello --reverse --n 3 
olleh olleh olleh world

% #{cmd} goodnight --help
Goodnight -- a fancy goodnight moon task
--------------------------------------------------------------------------------
  Says goodnight with a configurable message.
--------------------------------------------------------------------------------
usage: rap goodnight OBJECTS...

configurations:
        --message MESSAGE            a goodnight message
        --[no-]reverse               reverses the message
        --n N                        repeats message n times

options:
    -h, --help                       Print this help
        --name NAME                  Specify a name
        --use FILE                   Loads inputs from file
}
    end
    
    def test_stand_alone_goodnight_script
      script_test(method_root[:output]) do |cmd|
        File.open(method_root.filepath(:output, 'Tapfile'), 'w') do |file|
          file << %q{
#!/usr/bin/env ruby

require 'rubygems'
require 'tap'

# Goodnight::manifest a goodnight moon script
# Says goodnight with a configurable message.
class Goodnight < Tap::Task
  config :message, 'goodnight'

  def process(obj)
    puts "#{message} #{obj}\n"
  end
end

instance, args = Goodnight.parse!(ARGV)
instance.execute(*args)
}
        end
      
        FileUtils.chmod(method_root.filepath(:output, 'Tapfile'), 744)
      
        cmd.check "stand alone goodnight script", %q{
% ./goodnight moon
goodnight moon

% ./goodnight --help
Goodnight -- a fancy goodnight moon task
--------------------------------------------------------------------------------
  Says goodnight with a configurable message.
--------------------------------------------------------------------------------
usage: tap run -- goodnight OBJECTS...

configurations:
        --message MESSAGE            a goodnight message
        --[no-]reverse               reverses the message
        --n N                        repeats message n times

options:
    -h, --help                       Print this help
        --name NAME                  Specify a name
        --use FILE                   Loads inputs from file
}     
      end
    end
  end
end