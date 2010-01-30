require File.join(File.dirname(__FILE__), '../../tap_test_helper') 
require 'tap/tasks/dump'
require 'tap/test'
require 'stringio'

class DumpTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  Dump = Tap::Tasks::Dump
  
  attr_reader :io, :dump
  
  def setup
    super
    @io = StringIO.new
    @dump = Dump.new :output => io
  end
  
  #
  # process test
  #
  
  def test_process_dumps_the_input_as_a_string
    dump.process(1)
    assert_equal "1\n", io.string
  end
  
  def test_dumps_go_to_the_file_specified_by_output
    path = method_root.prepare('dump.yml')

    dump.output = path
    dump.process('input')
    assert_equal "input\n", File.read(path)
  end
  
  def test_sequential_dumps_append_a_file_target
    path = method_root.prepare('dump.yml')

    dump.output = path
    dump.process('input')
    dump.process('input')
    dump.process('input')
    assert_equal "input\ninput\ninput\n", File.read(path)
  end
  
  def test_sequential_dumps_overwrite_a_file_target_with_overwrite
    path = method_root.prepare('dump.yml')

    dump.output = path
    dump.overwrite = true
    dump.process('input')
    dump.process('input')
    dump.process('input')
    assert_equal "input\n", File.read(path)
  end
  
  def test_process_returns_the_input
    assert_equal 1, dump.process(1)
  end
  
end