require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/support/cdoc/register'

class RegisterTest < Test::Unit::TestCase
  include Tap::Support::CDoc
  
  attr_reader :r
  
  def setup
    @r = Register.new
  end
  
  #
  # key test
  #
  
  def test_key_expands_path_and_symbolizes
    assert_equal File.expand_path("path/to/key").to_sym, Register.key("path/to/key")
  end
  
  def test_key_returns_symbol_inputs
    assert_equal :symbol, Register.key(:symbol)
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    r = Register.new
    assert_equal({}, r.registry)
  end
  
  #
  # comments test
  #
  
  def test_comments_returns_value_for_the_source_file_in_registry
    r.registry[:source_file] = [1,2,3]
    assert_equal([1,2,3], r.comments(:source_file))
  end
  
  def test_comments_keyifies_source_file
    r.registry[Register.key('path/to/key')] = [1,2,3]
    assert_equal([1,2,3], r.comments('path/to/key'))
  end
  
  #
  # register test
  #
  
  def test_register_adds_line_number_to_source_file_in_registry_as_comment
    c1 = r.register(:source_file, 1)
    assert_equal 1, c1.line_number
    
    c2 = r.register(:source_file, 2)
    assert_equal 2, c2.line_number
    
    c3 = r.register(:source_file, 3)
    assert_equal 3, c3.line_number
    
    assert_equal({:source_file => [c1, c2, c3]}, r.registry)
  end
  
  def test_register_keyifies_source_file
    c1 = r.register('path/to/key', 1)
    assert_equal({ Register.key('path/to/key') => [c1]}, r.registry)
  end
  
  #
  # resolved? test
  #
  
  def test_resolved_returns_true_if_comments_for_source_file_are_frozen
    r.registry[:resolved] = [].freeze
    r.registry[:unresolved] = []
    
    assert r.resolved?(:resolved)
    assert !r.resolved?(:unresolved)
  end
  
  #
  # resolve test
  #
  
  def test_resolve_parses_comments_from_str_for_source_file
    str = %Q{
# comment one
# spanning multiple lines
#
#   indented line
#    
target line one

# comment two

target line two

# ignored
not a target line
}

    c1 = Comment.new(6)
    c2 = Comment.new(10)
    r.registry[:source_file] = [c1, c2]
    r.resolve(:source_file, str)
    
    assert_equal [['comment one', 'spanning multiple lines'], [''], ['  indented line'], ['']], c1.lines
    assert_equal "target line one", c1.target_line
    assert_equal 6, c1.line_number
    
    assert_equal [['comment two']], c2.lines
    assert_equal "target line two", c2.target_line
    assert_equal 10, c2.line_number
  end
  
  def test_resolve_freezes_comments_for_source_file
    array = []
    r.registry[:source_file] = array
    r.resolve(:source_file, "")
    
    assert array.frozen?
    assert r.registry[:source_file].frozen?
  end
  
  def test_resolve_reads_str_from_source_if_unspecified
    tempfile = Tempfile.new('register_test')
    tempfile << %Q{
# comment one
target line one
}
    tempfile.close
    
    c = r.register(tempfile.path, 2)
    r.resolve(tempfile.path)
    
    assert_equal [['comment one']], c.lines
    assert_equal "target line one", c.target_line
    assert_equal 2, c.line_number
  end
end