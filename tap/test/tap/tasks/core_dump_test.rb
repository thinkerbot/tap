require File.join(File.dirname(__FILE__), '../../tap_test_helper') 
require 'tap/tasks/core_dump'
require 'stringio'

class CoreDumpTest < Test::Unit::TestCase
  include Tap::Tasks
  Audit = Tap::Support::Audit
  acts_as_tap_test 
  
  attr_reader :io
  
  def setup
    @io = StringIO.new
    super
  end
  
  #
  # dump_to test
  #

  def test_dump_to_writes_aggregated_result_to_io_as_yaml
    t = Tap::Task.new({}, "name")
    
    a = Audit.new(t, 1)
    app.aggregator.store(a)
    b = Audit.new(t, 2)
    app.aggregator.store(b)
    assert_equal({t => [a,b]}, app.aggregator.to_hash)
    
    CoreDump.new(:date => false, :audit => false).dump_to(io)
    assert_equal %Q{--- 
name (#{t.object_id}): 
- 1
- 2
}, io.string
  end
  
  def test_dump_to_writes_audit_if_specified
    a = Audit.new(:a, 1)
    b = Audit.new(:b, 2, a)
    app.aggregator.store(b)
    
    CoreDump.new(:date => false, :audit => true).dump_to(io)
    assert io.string.gsub(/^# /, "").include?(b.dump)
  end
  
  def test_dump_to_writes_date_if_specified
    CoreDump.new(:date => true, :audit => false).dump_to(io)
    assert io.string =~ /# date: \d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/
  end
end