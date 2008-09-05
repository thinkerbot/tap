require File.join(File.dirname(__FILE__), '../tap_test_helper.rb') 
require 'tap/tasks/dump'
require 'stringio'

class DumpTest < Test::Unit::TestCase
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
    
    a = Audit.new._record(t, 1)
    app.aggregator.store(a)
    b = Audit.new._record(t, 2)
    app.aggregator.store(b)
    assert_equal({t => [a,b]}, app.aggregator.to_hash)
    
    Dump.new(:date => false, :audit => false).dump_to(io)
    assert_equal %Q{--- 
name (#{t.object_id}): 
- 1
- 2
}, io.string
  end
  
  def test_dump_to_writes_audit_if_specified
    a = Audit.new
    a._record(:a, 1)
    a._record(:b, 2)
    app.aggregator.store(a)
    
    Dump.new(:date => false, :audit => true).dump_to(io)
    assert io.string.gsub(/^# /, "").include?(a._to_s)
  end
  
  def test_dump_to_writes_date_if_specified
    Dump.new(:date => true, :audit => false).dump_to(io)
    assert io.string =~ /# date: \d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/
  end
  
  def test_dump_skips_objects_whose_to_s_does_not_match_filter
    t1 = Tap::Task.new({}, "name")
    a = Audit.new._record(t1, 1)
    app.aggregator.store(a)
    
    t2 = Tap::Task.new({}, "alt")
    b = Audit.new._record(t2, 2)
    app.aggregator.store(b)

    Dump.new(:date => false, :audit => false, :filter => /lt/).dump_to(io)
    assert_equal %Q{--- 
alt (#{t2.object_id}): 
- 2
}, io.string
    
    io.string = ""
    Dump.new(:date => false, :audit => false, :filter => /m/).dump_to(io)
    assert_equal %Q{--- 
name (#{t1.object_id}): 
- 1
}, io.string
  end
end