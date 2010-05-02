require File.join(File.dirname(__FILE__), '../../../test_helper.rb') 
require 'tap/tasks/dump/csv'
require 'stringio'

class DumpCsvTest < Test::Unit::TestCase
  acts_as_tap_test 
  acts_as_shell_test(SH_TEST_OPTIONS)
  
  Csv = Tap::Tasks::Dump::Csv

  #
  # documentation test
  #

  def test_documentation
    sh_test %q{
% tap load/yaml '["a", "b", "c"]' -: dump/csv
a,b,c
}
  end
  
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