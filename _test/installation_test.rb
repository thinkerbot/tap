require File.dirname(__FILE__) + "/test_helper"

class InstallationTest < Test::Unit::TestCase
  acts_as_shell_test
  acts_as_file_test
  
  def test_online_docs
    method_root.prepare("lib/goodnight.rb") do |io|
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
    Dir.chdir(method_root.root)
    
    with_env('TAP_GEMS' => '') do
      sh_test %q{
      % tap run -- goodnight moon --: dump
      goodnight moon
      }
    
      sh_test %q{
      % tap run -- load mittens -- load boat -- goodnight -- dump --[0,1][2] --[2][3]
      goodnight mittens
      goodnight boat
      }
      
      sh_test %Q{
      % tap run -T
      #{method_name}:
        goodnight   # your basic goodnight moon task
      tap:
        dump        # the default dump task
        load        # the default load task
      }
      
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
              --enque                      Manually enques self
              --config FILE                Specifies a config file
      }
    end
  end
end