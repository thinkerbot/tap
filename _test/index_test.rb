require File.expand_path('../test_helper', __FILE__)

class InstallationTest < Test::Unit::TestCase
  acts_as_shell_test
  acts_as_file_test
  
  def setup
    super
    @pwd = Dir.pwd
    method_root.chdir('.', true)
  end
  
  def teardown
    method_root.chdir(@pwd)
    super
  end
  
  def test_index_documentation
    method_root.prepare('tapfile') do |io|
      io << %q{
        # Constructs a configurable message for the input.

        desc "make a goodnight message"
        task :goodnight, :msg => 'goodnight' do |config, input|
          "#{config.msg} #{input}"
        end
      }
    end
    
    sh_test %q{
      % tap goodnight moon -: dump
      goodnight moon
    }
    
    sh_test %q{
      % tap goodnight world --msg hello -: dump
      hello world
    }
    
    sh_match %q{% tap goodnight moon -: dump --/use debugger},
        /0 << \["moon"\] \(Tapfile::Goodnight\)/
        /0 >> "goodnight moon" \(Tapfile::Goodnight\)/
        /1 << "goodnight moon" \(Tap::Tasks::Dump\)/
        /1 >> "goodnight moon" \(Tap::Tasks::Dump\)/
    
    sh_test %q{
      % tap goodnight --help
      Tapfile::Goodnight -- make a goodnight message
      --------------------------------------------------------------------------------
        Constructs a configurable message for the input.
      --------------------------------------------------------------------------------
      usage: tap tapfile/goodnight arg

      configurations:
              --msg MSG

      options:
              --help                       Print this help
              --config FILE                Specifies a config file
    }
    
    method_root.prepare('lib/goodnight.rb') do |io|
      io << %q{
        require 'tap/task'

        # ::task your basic goodnight moon task
        # Says goodnight with a configurable message.
        class Goodnight < Tap::Task
          config :msg, 'goodnight'           # a goodnight message

          def process(name)
            "#{msg} #{name}"
          end
        end
      }
    end
    
    method_root.prepare('test/goodnight_test.rb') do |io|
      io << %q{
        require 'tap/test/unit'
        require 'goodnight'

        class GoodnightTest < Test::Unit::TestCase
          acts_as_tap_test

          def test_goodnight_makes_the_configurable_message
            task = Goodnight.new
            assert_equal 'goodnight moon', task.process('moon')

            task = Goodnight.new :msg => 'hello'
            assert_equal 'hello world', task.process('world')
          end
        end
      }
    end
    
    sh_match 'ruby -rubygems -Ilib test/goodnight_test.rb',
      /0 failures/,
      /0 errors/

    method_root.prepare('tapfile') do |io|
      io << %q{
        desc "Iteration of inputs (copy-paste command line syntax)"
        work :iterate, %{
          -   load/yaml
          -:i goodnight
          -:  dump
        }

        desc "Forking and merging (literal definition of joins)"
        work :fork_and_merge, %{
          - load
          - goodnight --msg hi
          - goodnight --msg bye
          - dump
          - join 0 1,2
          - join 1,2 3
        }

        desc "Out of order, synchronized Merge (showcases full syntax)"
        work :ooo_sync, %{
          - dump
          - goodnight
          - goodnight
          - load
          - join 3 1,2
          - sync 1,2 0
        },{
          :one => 'hi',
          :two => 'bye'
        } do |config|
          node(1).msg = config.one
          node(2).msg = config.two
          node(3)  # the return is the entry point for the workflow, ie 'load'
        end
      }
    end
      
    sh_test %q{
      % tap iterate "[moon, mittens, 'little toy boat']"
      goodnight moon
      goodnight mittens
      goodnight little toy boat
    }
    
    sh_test %q{
      % tap fork_and_merge moon
      hi moon
      bye moon
    }
    
    if RUBY_VERSION >= '1.9'
      sh_test %q{
        % tap ooo_sync moon
        ["hi moon", "bye moon"]
      }
    
      sh_test %q{
        % tap ooo_sync moon --one hello --two goodnight
        ["hello moon", "goodnight moon"]
      }
    else
      sh_test %q{
        % tap ooo_sync moon
        hi moonbye moon
      }

      sh_test %q{
        % tap ooo_sync moon --one hello --two goodnight
        hello moongoodnight moon
      }
    end
  end
end