require File.join(File.dirname(__FILE__), '../tap_test_helper') 
require 'tap/dump'
require 'stringio'

class DumpTest < Test::Unit::TestCase
  include Tap
  Audit = Tap::Support::Audit
  acts_as_tap_test 
  
  attr_reader :io, :dump
  
  def setup
    super
    @io = StringIO.new
    @dump = Dump.new.setup(io)
  end
  
  #
  # instantiate test
  #
  
  def test_instantiate_uses_args_to_setup_dump
    dump, args = Dump.instantiate :args => %w{path/to/target.yml}
    
    assert_equal [], args
    assert_equal "path/to/target.yml", dump.target
  end
  
  #
  # process test
  #
  
  def test_process_dumps_the_audit_value_as_a_string
    a = Audit.new('a', 'value')
    
    dump.process(a)
    assert_equal "value\n", io.string
  end
  
  def test_process_dumps_the_audit_if_specified
    a = Audit.new('a', 1)
    b = Audit.new('b', 2, a)
    
    dump.audit = true
    dump.process(b)
    assert_equal %Q{
# audit:
# o-[a] 1
# o-[b] 2
# 
2
}, "\n" + io.string
  end
  
  def test_dumps_go_to_the_file_specified_by_target
    a = Audit.new('a', 'value')
    path = method_root.prepare(:tmp, 'dump.yml')

    dump.target = path
    dump.process(a)
    assert_equal "value\n", File.read(path)
  end
  
  def test_sequential_dumps_append_a_file_target
    a = Audit.new('a', 'value')
    path = method_root.prepare(:tmp, 'dump.yml')

    dump.target = path
    dump.process(a)
    dump.process(a)
    dump.process(a)
    assert_equal "value\nvalue\nvalue\n", File.read(path)
  end
end