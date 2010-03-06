require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/command'
require 'tap/generator/preview.rb'
require 'stringio'

class CommandGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  acts_as_tap_test
  
  def setup
    super
    @current_stdout = $stdout
    $stdout = StringIO.new
    @current_argv = ARGV
    ARGV.clear
  end
  
  def teardown
    super
    ARGV.concat(@current_argv)
    $stdout = @current_stdout
  end
  #
  # process test
  #
  
  def test_command_generator
    c = Command.new.extend Preview
    
    assert_equal %w{
      cmd
      cmd/command_name.rb
    }, c.process('command_name')
    
    assert_equal [], ARGV
    assert_equal "", $stdout.string
    
    # test the command prints the app info to stdout
    eval c.preview['cmd/command_name.rb']
    assert_equal %q{
Received: 
state: 0 (READY) queue: 0
}, "\n" + $stdout.string

    # now test the help
    $stdout.string = ""
    ARGV << "--help"
    
    cmd_file = method_root.prepare('cmd') {|file| file << c.preview['cmd/command_name.rb'] }
    assert_raise(SystemExit) { load(cmd_file) }
    
    assert_equal %q{
tap command_name {options} ARGS...

The default command simply prints the input arguments and application
information, then exits.

options:
    -h, --help                       Show this message
}, "\n" + $stdout.string
  end
end