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
    @dump = Dump.new({:date => false, :audit => false}, nil, app, io)
  end
  
  #
  # parse! test
  #
  
  def test_parse_uses_args_to_setup_dump
    dump, args = Dump.parse %w{path/to/target.yml --date --no-audit}
    
    assert_equal [], args
    assert_equal "path/to/target.yml", dump.target
    assert_equal true, dump.date
    assert_equal false, dump.audit
  end

  #
  # _execute test
  #

  def test__execute_merges_inputs
    a = Audit.new('a', 'A')
    c = Audit.new('c', 'C')
    
    _result = dump._execute(a, 'B', c)
    
    assert_equal [[['a'], [nil], ['c']], dump], _result.trail {|audit| audit.key }
    assert_equal [[['A'], ['B'], ['C']], ['A', 'B', 'C']], _result.trail {|audit| audit.value }
  end
  
  def test__execute_does_not_join_audits_if_app_audit_is_false
    a = Audit.new('a', 'A')
    c = Audit.new('c', 'C')
    
    app.audit = false
    _result = dump._execute(a, 'B', c)
    
    assert_equal [dump], _result.trail {|audit| audit.key }
    assert_equal [['A', 'B', 'C']], _result.trail {|audit| audit.value }
  end
  
  def test_process_receives_the_merged_input
    a = Audit.new('a', 'A')
    c = Audit.new('c', 'C')
    
    was_in_block = false
    dump = Dump.intern do |task, _audit|
      assert_equal [[['a'], [nil], ['c']], dump], _audit.trail {|audit| audit.key }
      assert_equal [[['A'], ['B'], ['C']], ['A', 'B', 'C']], _audit.trail {|audit| audit.value } 
      was_in_block = true
    end
    
    dump._execute(a, 'B', c)
    assert was_in_block
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