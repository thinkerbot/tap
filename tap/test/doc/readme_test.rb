require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/test/unit'

class ReadmeTest < Test::Unit::TestCase 
  extend Tap::Test
  TAP_ROOT = File.expand_path("../../..", __FILE__)
  
  acts_as_file_test
  acts_as_shell_test
  
  def setup
    super
    @pwd = Dir.pwd
    method_root.chdir('.', true)
  end
  
  def teardown
    Dir.chdir(@pwd)
    super
  end
  
  def sh_test_options
    {
      :cmd_pattern => "% tap", 
      :cmd => [
        "ruby",
        "-I'#{TAP_ROOT}/../configurable/lib'",
        "-I'#{TAP_ROOT}/../lazydoc/lib'",
        "-I'#{TAP_ROOT}/lib'",
        "'#{TAP_ROOT}/bin/tap'"
      ].join(" "),
      :indents => true,
      :env => default_env,
      :replace_env => false
    }
  end
  
  def default_env
    {
      'HOME' => method_root.path('home'),
      'TAPFILE'  => '',
      'TAP_GEMS' => '', 
      'TAP_PATH' => "#{TAP_ROOT}:.",
      'TAPENV'   => '',
      'TAPRC'    => '',
      'TAP_GEMS' => ''
    }
  end
  
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
      % tap manifest
      task:
        dump                 # the default dump task
        goodnight            # your basic goodnight moon task
        load                 # the default load task
        manifest             # lists resources
        prompt               # an input prompt
      join:
        gate                 # collects results before the join
        join                 # an unsyncrhonized, multi-way join
        sync                 # a synchronized multi-way join
      middleware:
        debugger             # the default debugger
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
    
    # sometimes a sh_test will transpose the last two lines... I'm
    # assuming because of variations in when stdin and stdout flush
    actual = sh_test "% tap goodnight moon -: dump --/use debugger 2>&1"
    expected = %q{
+ 0 ["moon"]
- 0 "goodnight moon"
+ 1 "goodnight moon"
goodnight moon
- 1 "goodnight moon"
}.strip
    assert_equal expected.split("\n").sort, actual.split("\n").sort
    
    method_root.prepare('tapfile') do |io|
      # don't use indents so grep output is correct
      io << %q{
require 'tap/declarations'
include Tap::Declarations

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
end