require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/test/unit'

class SetupTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  include TapTestMethods

  def test_TAPFILE_doc
    method_root.prepare('tapfile') do |io|
      io << %q{
        require 'tap/declarations'
        Tap.task :goodnight do |task, arg|
          "Goodnight #{arg}!"
        end
      }
    end
    
    sh_test %q{
      % tap goodnight Moon -: dump
      Goodnight Moon!
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
  end

  # def test_TAP_GEMS_doc
  #   % gem install tap-tasks
  #   % TAP_GEMS=. tap inspect string
  #   "string"
  #   % TAP_GEMS=tap-ta* tap inspect string
  #   "string"
  #   % TAP_GEMS=nomatch tap inspect string
  #   unresolvable constant: 'inspect' (RuntimeError)
  #   % TAP_GEMS= tap inspect string
  #   unresolvable constant: 'inspect' (RuntimeError)
  # end
  
  def test_TAP_PATH_doc
    method_root.prepare('dir/lib/goodnight.rb') do |io|
      io << %q{
        require 'tap/task'
        
        # ::task
        class Goodnight < Tap::Task
          def process(input)
            puts "goodnight #{input}"
          end
        end
      }
    end
    
    sh_test %q{
      % tap goodnight moon
      unresolvable constant: "goodnight" (RuntimeError)
    }, :env => default_env.merge('TAP_PATH' => '.')
    
    sh_test %q{
      % tap goodnight moon
      goodnight moon
    }, :env => default_env.merge('TAP_PATH' => 'dir')
  end

  def test_TAPENV_doc
    method_root.prepare('tapenv') do |io|
      io << %q{
        unset Tap::Tasks::Dump
      }
    end
    
    sh_test %q{
      % tap load a -: dump
      unresolvable constant: "dump" (RuntimeError)
    }, :env => default_env.merge('TAPENV' => 'tapenv')
  end

  def test_TAPRC_doc
    method_root.prepare('taprc') do |io|
      io << %q{
        set loader load
        set dumper dump
      }
    end
    
    sh_test %q{
      % tap - join loader dumper -/enq loader 'goodnight moon'
      goodnight moon
    }, :env => default_env.merge('TAPRC' => 'taprc')
  end
end