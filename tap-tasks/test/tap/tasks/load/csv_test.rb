require File.join(File.dirname(__FILE__), '../../../test_helper.rb') 
require 'tap/tasks/load/csv'

class LoadCsvTest < Test::Unit::TestCase
  acts_as_tap_test 
  
  Csv = Tap::Tasks::Load::Csv

  #
  # process test
  #
  
  def test_csv_loads_an_array_of_arrays_from_csv_data
    task = Csv.new
    assert_equal [
      ['a', 'b', 'c'],
      ['d', 'e'],
      ['x', 'y', 'z']
    ], task.process("a,b,c\nd,e\nx,y,z")
  end
  
  def test_csv_selects_specified_rows_and_columns
    task = Csv.new :rows => 1..2, :columns => 1..2
    assert_equal [
      ['e'],
      ['y', 'z']
    ], task.process("a,b,c\nd,e\nx,y,z")
  end
  
  def test_csv_parses_based_on_row_and_col_separators
    task = Csv.new :row_sep => '.', :col_sep => ':'
    assert_equal [
      ['a', 'b', 'c'],
      ['d', 'e'],
      ['x', 'y', 'z']
    ], task.process("a:b:c.d:e.x:y:z")
  end
end