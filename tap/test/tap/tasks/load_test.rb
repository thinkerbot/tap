require File.expand_path('../../../test_helper', __FILE__) 
require 'tap/tasks/load'

class Tap::LoadTest < Test::Unit::TestCase
  acts_as_tap_test
  acts_as_shell_test
  include TapTestMethods
  Load = Tap::Tasks::Load
  
  attr_accessor :load
  
  def setup
    super
    @load = Load.new
  end
  
  def io(obj)
    StringIO.new YAML.dump(obj)
  end
  
  #
  # documentation test
  #
  
  def test_load_documentation
    sh_test %q{
      % tap load string -: dump
      string
    }
    
    tap = sh_test_options[:cmd]
    sh_test %Q{
      echo goodnight moon | #{tap} load -: dump
      goodnight moon
    }
    
    somefile = method_root.prepare('somefile.txt') do |io|
      io << 'contents of somefile'
    end
    
    sh_test %Q{
      % tap load -: dump < '#{somefile}'
      contents of somefile
    }
  end
  
  #
  # process test
  #
  
  def test_process_reads_input
    str = YAML.dump({'one' => 1, 'two' => 2, 'three' => 3})
    io = StringIO.new(str)
    assert_equal(str, load.process(io))
  end

  def test_process_return_string_inputs
    assert_equal("string", load.process("string"))
  end
  
  def test_process_closes_io_when_use_close_is_true
    io = StringIO.new
    load.process(io)
    assert !io.closed?
    
    load.use_close = true
    load.process(io)
    assert io.closed?
  end
end