require File.join(File.dirname(__FILE__), '../doc_test_helper')
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class ReadmeDoc < Test::Unit::TestCase 
  include Doctest
  include MethodRoot
  
  def test_readme
    method_root.prepare(:sample, 'lib/goodnight.rb') do |io|
      io << %q{
      # Goodnight::task your basic goodnight moon task
      # Says goodnight with a configurable message.
      class Goodnight < Tap::Task
        config :message, 'goodnight'           # a goodnight message
        def process(name)
          "#{message} #{name}"
        end
      end}
    end
    method_root.prepare(:sample, 'tap.yml') {|io| io << "gems: []"}
    
    method_root.chdir(:sample) do
      sh_test "print manifest", %q{
% tap run -T
sample:
  goodnight   # your basic goodnight moon task
tap:
  dump        # the default dump task
  load        # the default load task
}
      
      sh_test "print help", %q{
% tap run -- goodnight --help
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
}

      sh_test "run goodnight task", %q{
% tap run -- goodnight moon --: dump
goodnight moon
}
    end
  end
end