require File.join(File.dirname(__FILE__), '../tap_test_helper') 
require 'tap/load'

class Tap::LoadTest < Test::Unit::TestCase
  include Tap 
  
  attr_accessor :load, :method_root
  
  def setup
    super
    @load = Load.new
    @method_root = Tap::Root.new("#{__FILE__.chomp(".rb")}_#{method_name}")
  end
  
  def teardown
    # clear out the output folder if it exists, unless flagged otherwise
    unless ENV["KEEP_OUTPUTS"]
      FileUtils.rm_r(method_root.root) if File.exists?(method_root.root)
    end
  end
  
  def io(obj)
    StringIO.new YAML.dump(obj)
  end
  
  #
  # process test
  #
  
  def test_process_reads_input
    str = YAML.dump({'one' => 1, 'two' => 2, 'three' => 3})
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