require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/test/unit'
require 'tap/version'
require 'rbconfig'

class SetupTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  acts_as_subset_test
  include TapTestMethods

  def test_tap_sets_default_env_when_run_through_rubygems
    extended_test do
      gem_test do |gem_env|
        gem_env.keys.each {|key| gem_env[key] = nil if key =~ /^TAP/ }
        tap_path = method_root.path('gem/bin/tap')
        
        sh_test %Q{
          '#{tap_path}' -d- 2>&1
                  ruby: #{RbConfig::CONFIG['RUBY_INSTALL_NAME']}-#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})
                   tap: #{Tap::VERSION}
               tapfile: tapfile
                  gems: .
              generate: tap-#{Tap::VERSION}
                  path: .
                tapenv: tapenv
                 taprc: ~/.taprc:taprc
        }, :env => gem_env
      end
    end
  end
  
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

  def test_TAP_GEMS_doc
    extended_test do
      gem_test do |gem_env|
        sh_gem("gem install '#{build_gem("tap-tasks")}' --local --no-rdoc --no-ri", :env => gem_env)
        
        sh_test %q{
          % tap inspect a b c
          ["a", "b", "c"]
        }, :env => gem_env.merge('TAP_GEMS' => '.')
        
        sh_test %q{
          % tap inspect a b c
          ["a", "b", "c"]
        }, :env => gem_env.merge('TAP_GEMS' => 'tap-ta*')
        
        sh_test %q{
          % tap inspect a b c
          unresolvable constant: "inspect" (RuntimeError)
        }, :env => gem_env.merge('TAP_GEMS' => 'nomatch')
        
        sh_test %q{
          % tap inspect a b c
          unresolvable constant: "inspect" (RuntimeError)
        }, :env => gem_env.merge('TAP_GEMS' => '')
      end
    end
  end
  
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