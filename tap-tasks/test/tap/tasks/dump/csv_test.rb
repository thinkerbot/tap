require File.join(File.dirname(__FILE__), '../../../tap_test_helper.rb') 
require 'tap/tasks/dump/csv'
require 'stringio'

class DumpCsvTest < Test::Unit::TestCase
  acts_as_tap_test 
  
  Csv = Tap::Tasks::Dump::Csv

  #
  # process test
  #
  
  def test_csv_dumps_an_array_as_csv_to_output
    output = StringIO.new
    
    task = Csv.new :output => output
    task.process(["a", "b", "c"])
    task.process(["d", "e"])
    
    assert_equal "a,b,c\nd,e\n", output.string
  end
  
  def test_csv_dumps_based_on_row_and_col_separators
    output = StringIO.new
    task = Csv.new :row_sep => '.', :col_sep => ':', :output => output
    task.process(["a", "b", "c"])
    task.process(["d", "e"])
    
    assert_equal "a:b:c.d:e.", output.string
  end
end