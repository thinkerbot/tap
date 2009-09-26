require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'
require 'tap/test'

class ReadmeDoc < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test :cleanup_dirs => [:sample]
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
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
      
      # print manifest
      sh_test %q{
% tap run -T
sample:
  goodnight   # your basic goodnight moon task
tap:
  dump        # the default dump task
  load        # the default load task
}
      
      # print help 
      sh_test %q{
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
        --enque                      Enques self with args
        --config FILE                Specifies a config file
}
      
      # run goodnight task
      sh_test %q{
% tap run -- goodnight moon --: dump
goodnight moon
}
    end
  end
end