require File.expand_path('../../test_helper', __FILE__)
require 'tap/version'

class ReadmeTest < Test::Unit::TestCase
  acts_as_file_test
  acts_as_shell_test
  acts_as_subset_test
  include TapTestMethods
  
  def test_readme
    method_root.prepare('lib/goodnight.rb') do |io|
      io << %q{
      require 'tap/task'
      
      # Goodnight::task your basic goodnight moon task
      # Says goodnight with a configurable message.
      class Goodnight < Tap::Task
        config :message, 'goodnight'           # a goodnight message

        def process(name)
          "#{message} #{name}"
        end
      end
      }
    end
    
    sh_test %q{
      % tap list
      task:
        dump                 # dump data
        goodnight            # your basic goodnight moon task
        list                 # list resources
        load                 # load data
        prompt               # open a prompt
        signal               # signal via a task
      join:
        gate                 # collects results
        join                 # unsyncrhonized multi-way join
        sync                 # synchronized multi-way join
      middleware:
        debugger             # default debugger
    }
    
    sh_test %q{
      % tap goodnight --help
      Goodnight -- your basic goodnight moon task
      --------------------------------------------------------------------------------
        Says goodnight with a configurable message.
      --------------------------------------------------------------------------------
      usage: tap goodnight NAME

      configurations:
              --message MESSAGE            a goodnight message

      options:
              --help                       Print this help
              --config FILE                Specifies a config file
    }
    
    sh_test %q{
      % tap goodnight moon -: dump
      goodnight moon
    }
    
    sh_test %q{
      % tap goodnight world --message hello -: dump
      hello world
    }
    
    sh_match "% tap goodnight moon -: dump --/use debugger 2>&1",
      /0 << \["moon"\] \(Goodnight\)/,
      /0 >> "goodnight moon" \(Goodnight\)/,
      /1 << "goodnight moon" \(Tap::Tasks::Dump\)/,
      /1 >> "goodnight moon" \(Tap::Tasks::Dump\)/
    
    # (see below)
    # class ShellTestTest < Test::Unit::TestCase
    
    # much setup is required to test the gem install cleanly
    # and so it has been put into it's own test 
    
    method_root.prepare('tapfile') do |io|
      # don't use indents so grep output is correct
      io << %q{
desc "concat file contents"
task :cat do |config, *files|
  files.collect {|file| File.read(file) }.join
end

desc "grep lines"
task :grep, :e => '.' do |config, str|
  str.split("\n").grep(/#{config.e}/)
end
}
    end
    
    sh_test %q{
    % tap cat tapfile -:a grep -e task -:i dump
    task :cat do |config, *files|
    task :grep, :e => '.' do |config, str|
    }, :env => default_env.merge('TAPFILE' => 'tapfile')
  end
  
  # class ShellTestTest < Test::Unit::TestCase
  def test_goodnight_moon
    sh_test %q{
    % tap load 'goodnight moon' -: dump
    goodnight moon
    }
  end
  
  def test_gem_install_readme
    extended_test do
      gem_test do |gem_env|
        gem_env.merge!('TAP_GEMS' => '.')
        tap_path = method_root.path('gem/bin/tap')
        
        sh_test %Q{
          '#{tap_path}' load/yaml 2>&1
          unresolvable constant: "load/yaml"
        }, :env => gem_env
      
        sh_gem("gem install '#{build_gem("tap-tasks")}' --local --no-rdoc --no-ri", :env => gem_env)
        
        sh_test %Q{
          '#{tap_path}' load/yaml "[1, 2, 3]" -: dump/yaml 2>&1
          --- 
          - 1
          - 2
          - 3
        }, :env => gem_env
      end
    end
  end
end
