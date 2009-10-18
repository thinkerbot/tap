require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class TutorialTest < Test::Unit::TestCase 
  root = File.expand_path(File.dirname(__FILE__) + "/../../..")
  LOAD_PATHS = [
    "-I'#{root}/configurable/lib'",
    "-I'#{root}/lazydoc/lib'",
    "-I'#{root}/tap/lib'",
    "-I'#{root}/rap/lib'",
    "-I'#{root}/tap-gen/lib'"
  ]
  
  acts_as_file_test
  acts_as_shell_test(
    :cmd_pattern => "% rap",
    :cmd => (["ruby"] + LOAD_PATHS + ["'#{root}/rap/bin/rap'"]).join(" "),
    :env => {'TAP_GEMS' => ''}
  )
  
  def test_declaration
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
# :: your basic goodnight moon task
# Says goodnight with a configurable message.
Rap.task(:goodnight, :obj, :message => 'goodnight') do |task, args|
  puts "#{task.message} #{args.obj}"
end}
    end
          
    method_root.chdir(:tmp) do
      sh_test %q{
% rap goodnight moon
goodnight moon
}
      sh_test %q{
% rap goodnight world --message hello
hello world
}
      sh_test %q{
% rap goodnight --help
Goodnight -- your basic goodnight moon task
--------------------------------------------------------------------------------
  Says goodnight with a configurable message.
--------------------------------------------------------------------------------
usage: tap run -- goodnight OBJ

configurations:
        --message MESSAGE

options:
        --help                       Print this help
        --enque                      Manually enques self
        --config FILE                Specifies a config file
}
    end
  end
  
  def test_rake_style_declaration
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
# make the declarations available everywhere
include Rap::Declarations

namespace :example do
  task(:say, :message) do |task, args|
    print(args.message || 'goodnight')
  end

  desc "your basic goodnight moon task"
  task({:goodnight => 'example:say'}, :obj) do |task, args|
    puts " #{args.obj}"
  end
end}
    end
    
    method_root.chdir(:tmp) do
      sh_test %q{
% rap goodnight moon
goodnight moon
}
      sh_test %q{
% rap say hello -- goodnight world
hello world
}
    end
    
    method_root.prepare(:tmp, 'Rakefile') do |file|
      file << %q{
require 'rake'

task(:Say, :message) do |task, args|
  print(args.message || 'goodnight')
end

task(:Goodnight, :obj, :needs => :Say) do |task, args|
  print " #{args.obj}\n"
end
}
    end

    method_root.chdir(:tmp) do
      sh_test %Q{
rake Say[hello] Goodnight[world]
(in #{method_root[:tmp]})
hello world
}
      sh_test %Q{
% rap Say[hello] Goodnight[world] 2>&1
warning: implict rake for [:node, "0", "Say[hello]", "Goodnight[world]"]
(in #{method_root[:tmp]})
hello world
}
      sh_test %Q{
% rap Say[hello] Goodnight[world] -- goodnight moon 2>&1
warning: implict rake for [:node, "0", "Say[hello]", "Goodnight[world]"]
(in #{method_root[:tmp]})
hello world
goodnight moon
}
    end
  end
  
  # Goodnight::task your basic goodnight moon task
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
    method_root.prepare(:tmp,'lib/goodnight.rb') do |file|
        file << %q{
# Goodnight::task a fancy goodnight moon task
# Says goodnight with a configurable message.
class Goodnight < Tap::Task
  config :message, 'goodnight'           # a goodnight message
  config :reverse, false, &c.switch      # reverses the message
  config :n, 1, &c.integer               # repeats message n times

  def process(*objects)
    msg = "#{reverse == true ? message.reverse : message} " * n
    msg + objects.join(', ')
  end
end
}
    end

    method_root.chdir(:tmp) do
      sh_test %q{
% rap goodnight moon --: dump
goodnight moon
}
      sh_test %q{
% rap goodnight moon mittens "little toy boat" --: dump
goodnight moon, mittens, little toy boat
}
      sh_test %q{
% rap goodnight world --message hello --reverse --n 3 --: dump
olleh olleh olleh world
}
      sh_test %q{
% rap goodnight --help
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
        --help                       Print this help
        --enque                      Manually enques self
        --config FILE                Specifies a config file
}
    end
  end
  
  def test_stand_alone_goodnight_script
    path = method_root.prepare(:tmp, 'goodnight') do |file|
        file << %q{
#!/usr/bin/env ruby

require 'rubygems'
require 'tap'

# Goodnight::task a goodnight moon script
# Says goodnight with a configurable message.
class Goodnight < Tap::Task
  config :message, 'goodnight'

  def process(obj)
    puts "#{message} #{obj}\n"
  end
end

instance, args = Goodnight.parse!(ARGV)
instance.execute(args)
}
    end
    
    FileUtils.chmod(774,path)
    method_root.chdir(:tmp) do
      assert_equal "goodnight moon\n", sh("ruby #{LOAD_PATHS.join(' ')} goodnight moon")
      
      result = sh("ruby #{LOAD_PATHS.join(' ')} goodnight --help")
      assert result =~ /Goodnight -- a goodnight moon script/
    end
  end
end