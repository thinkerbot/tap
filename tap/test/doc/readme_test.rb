require File.join(File.dirname(__FILE__), '../tap_test_helper')

class ReadmeTest < Test::Unit::TestCase 
  acts_as_script_test
  
  cleanup_dirs << 'sample'

  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
  LOAD_PATHS = $:.collect {|path| "-I'#{File.expand_path(path)}'"}.uniq.join(' ')
  
  def default_command_path
    %Q{ruby #{LOAD_PATHS} "#{TAP_EXECUTABLE_PATH}"}
  end
  
  def test_readme
    method_root.prepare(:sample, 'lib/goodnight.rb') do |io|
      io << %q{
      # Goodnight::manifest your basic goodnight moon task
      # Says goodnight with a configurable message.
      class Goodnight < Tap::Task

        config :message, 'goodnight'           # a goodnight message

        def process(name)
          log(message, name)
          "#{message} #{name}"
        end
      end}
    end
    method_root.prepare(:sample, 'tap.yml') {}
    
    script_test(method_root[:sample]) do |cmd|
      cmd.check "Prints help for the goodnight moon task", %Q{
% #{cmd} run -T
sample:
  goodnight   # your basic goodnight moon task
tap:
  dump        # the default dump task
  load        # the default load task
% #{cmd} run -- goodnight --help
Goodnight -- your basic goodnight moon task
--------------------------------------------------------------------------------
  Says goodnight with a configurable message.
--------------------------------------------------------------------------------
usage: tap run -- goodnight NAME

configurations:
        --message MESSAGE            a goodnight message

options:
        --help                       Print this help
        --name NAME                  Specifies the task name
        --config FILE                Specifies a config file
}, false

      cmd.check "Runs the goodnight moon task", %Q{
% #{cmd} run -- goodnight moon
  I[:...:]          goodnight moon
}
    end
  end
end