require File.join(File.dirname(__FILE__), '../tap_test_helper') 
require 'tap/load'

class Tap::LoadTest < Test::Unit::TestCase
  include Tap
  
  acts_as_tap_test 
  
  attr_accessor :load
  
  def setup
    super
    @load = Load.new
  end
  
  def io(obj)
    StringIO.new(obj.to_yaml)
  end
  
  #
  # process test
  #
  
  def test_process_reads_input
    str = {'one' => 1, 'two' => 2, 'three' => 3}.to_yaml
    io = StringIO.new(str)
    assert_equal(str, load.process(io))
  end
  
  def test_process_loads_input_from_file_if_file_is_specified
    path = method_root.prepare(:tmp, 'file.txt') {|file| file << "contents" }
    load.file = true
    assert_equal("contents", load.process(path))
  end
  
  def test_process_return_string_inputs
    assert_equal("string", load.process("string"))
  end
end