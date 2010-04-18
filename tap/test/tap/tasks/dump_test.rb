require File.expand_path('../../../tap_test_helper', __FILE__) 
require 'tap/tasks/dump'
require 'stringio'

class DumpTest < Test::Unit::TestCase
  acts_as_tap_test
  acts_as_shell_test
  include TapTestMethods
  Dump = Tap::Tasks::Dump
  
  attr_reader :io, :dump
  
  def setup
    super
    @io = StringIO.new
    @dump = Dump.new :output => io
  end
  
  #
  # documentation test
  #
  
  def test_dump_documentation
    filepath = method_root.prepare('filepath')
    sh_test %Q{
      % tap dump content --output '#{filepath}'
    }
    
    if RUBY_VERSION < '1.9'
      assert_equal "content\n", File.read(filepath)
    else
      assert_equal %Q{["content"]\n}, File.read(filepath)
    end
    
    sh_test %q{
      % tap load 'goodnight moon' -: dump | more
      goodnight moon
    }
    
    results = method_root.prepare('results.txt')
    sh_test %Q{
      % tap load 'goodnight moon' -: dump 1> '#{results}'
    }
    
    sh_test %Q{
      more '#{results}'
      goodnight moon
    }
    
    if RUBY_VERSION < '1.9'
      sh_test %q{
        % tap load goodnight -- load moon - dump - sync 0,1 2
        goodnightmoon
      }
    else
      sh_test %q{
        % tap load goodnight -- load moon - dump - sync 0,1 2
        ["goodnight", "moon"]
      }
    end
    
    sh_test %q{
      % tap load goodnight -- load moon - dump - sync 0,1 2 -i
      goodnight
      moon
    }
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