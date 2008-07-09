require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class ConfigurationTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :c
  def setup
    @c = Configuration.new('name')
  end
  
  #
  # Configuration.shortify test
  #
  
  def test_shortify_documentation
    assert_equal "-o", Configuration.shortify("-o")
    assert_equal "-o", Configuration.shortify(:o)
  end
  
  def test_shortify_formats_str_as_short_option
    assert_equal "-o", Configuration.shortify("-o")
    assert_equal "-O", Configuration.shortify("-O")
    
    assert_equal "-o", Configuration.shortify("o")
    assert_equal "-O", Configuration.shortify("O")
  end
  
  def test_shortify_stringifies_input
    assert_equal "-o", Configuration.shortify('-o'.to_sym)
    assert_equal "-o", Configuration.shortify(:o)
  end
  
  def test_shortify_raises_error_for_shorts_that_dont_match_SHORT_REGEXP
    assert_raise(RuntimeError) { Configuration.shortify("-1") }
    assert_raise(RuntimeError) { Configuration.shortify("1") }
    assert_raise(RuntimeError) { Configuration.shortify("bogus") }
    assert_raise(RuntimeError) { Configuration.shortify("#") }
    assert_raise(RuntimeError) { Configuration.shortify("-") }
    assert_raise(RuntimeError) { Configuration.shortify("") }
  end
  
  #
  # Configuration.longify test
  #
  
  def test_longify_documentation
    assert_equal "--opt", Configuration.longify("--opt")
    assert_equal "--opt", Configuration.longify(:opt)
    assert_equal "--[no-]opt", Configuration.longify(:opt, true)
    assert_equal "--opt-ion", Configuration.longify(:opt_ion)
    assert_equal "--opt_ion", Configuration.longify(:opt_ion, false, false)
  end
  
  def test_longify_formats_str_as_long_option
    assert_equal "--opt", Configuration.longify("--opt")
    assert_equal "--opt", Configuration.longify("opt")
  end
  
  def test_longify_stringifies_input
    assert_equal "--opt", Configuration.longify('--opt'.to_sym)
    assert_equal "--opt", Configuration.longify(:opt)
  end
  
  def test_longify_with_switch_format_adds_no_string_if_necessary
    assert_equal "--[no-]opt", Configuration.longify('opt', true)
    assert_equal "--[no-]opt", Configuration.longify('[no-]opt', true)
    assert_equal "--[no-]opt", Configuration.longify('--[no-]opt', true)
  end
  
  def test_longify_with_hyphenize_gsubs_underscore_for_hyphen
    assert_equal "--opt-ion", Configuration.longify('opt_ion', false, true)
  end
  
  def test_longify_raises_error_for_shorts_that_dont_match_LONG_REGEXP
    assert_raise(RuntimeError) { Configuration.longify("-0") }
    assert_raise(RuntimeError) { Configuration.longify("--0") }
    assert_raise(RuntimeError) { Configuration.longify("--[blah-]option") }
    assert_raise(RuntimeError) { Configuration.longify("--@!") }
    assert_raise(RuntimeError) { Configuration.longify("_option", false, true) }
    assert_raise(RuntimeError) { Configuration.longify("") }
  end
  
  #
  # parse_register test
  #
  
  def test_parse_register_returns_array_of_summary_and_descs_at_specified_lines
    str = %Q{
# some multiline
# description
config :key, 'value' # summary one

# another multiline
# description
config :key, 'value' # summary two
}
    assert_equal [
      {:summary => 'summary one', :desc => ''}, # [['some multiline', 'description']]
      {:summary => 'summary two', :desc => ''} # [['another multiline', 'description']]
    ], Configuration.parse_register(str, [4, 8])
  end
  
  def test_parse_register_skips_malformatted_config_lines
    str = %Q{
broken_config :key, 'value' # summary one
config :key, 'value' # summary two
}
    assert_equal [
      {:summary => nil, :desc => ''}, # [['some multiline', 'description']]
      {:summary => 'summary two', :desc => ''} # [['another multiline', 'description']]
    ], Configuration.parse_register(str, [2, 3])
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Configuration.new('name')
    assert_equal 'name', c.name
    assert_equal nil, c.default
    assert_equal :name, c.reader
    assert_equal :name=, c.writer
    assert_equal :mandatory, c.arg_type
    
    c = Configuration.new('name', 'default', {:arg_type => :optional, :reader => :alt, :writer => :alt=})
    assert_equal 'name', c.name
    assert_equal 'default', c.default
    assert_equal :alt, c.reader
    assert_equal :alt=, c.writer
    assert_equal :optional, c.arg_type
  end
  
  #
  # default= test
  #
  
  def test_set_default_sets_default
    assert_nil c.default
    c.default = 1
    assert_equal 1, c.default
  end
  
  def test_set_default_sets_duplicable_to_false_if_default_cannot_be_duplicated
    [nil, 1, 1.1, true, false, :sym].each do |non_duplicable_default|
      c.default = non_duplicable_default
      assert !c.duplicable
    end
  end
  
  def test_set_default_sets_duplicable_to_true_if_default_can_be_duplicated
    [{}, [], Object.new].each do |duplicable_default|
      c.default = duplicable_default
      assert c.duplicable
    end
  end
  
  def test_set_default_freezes_object
    a = []
    assert !a.frozen?
    c.default = a
    assert a.frozen?
  end
  
  def test_non_freezable_objects_are_not_frozen
    c.default = 1
    assert !c.default.frozen?
    
    c.default = :sym
    assert !c.default.frozen?
    
    c.default = nil
    assert !c.default.frozen?
  end
  
  #
  # default test
  #

  def test_default_returns_default
    assert_equal nil, c.default
    
    c.default = 'value'
    assert_equal 'value', c.default
  end
  
  def test_default_returns_duplicate_values
    a = [1,2,3]
    c.default = a
  
    assert_equal a, c.default
    assert_not_equal a.object_id, c.default.object_id
  end
  
  def test_default_does_not_duplicate_if_specified
    a = [1,2,3]
    c.default = a
  
    assert_equal a, c.default(false)
    assert_equal a.object_id, c.default(false).object_id
  end
  
  #
  # to_option_parser_argv test
  #
  
  #
  # reader= test
  #

  def test_set_reader_symbolizes_input
    c.reader = 'reader'
    assert_equal :reader, c.reader
  end
  
  #
  # writer= test
  #

  def test_set_writer_symbolizes_input
    c.writer = 'writer='
    assert_equal :writer=, c.writer
  end  
  
  #
  # == test
  #
  
  def test_another_is_equal_to_self_if_all_attributes_are_equal
    config = Configuration.new('name')
    another = Configuration.new('name')
    assert config == another
    
    config = Configuration.new('name')
    another = Configuration.new('alt')
    assert config != another
    
    config = Configuration.new('name', 1)
    another = Configuration.new('name', 2)
    assert config != another
    
    config = Configuration.new('name', 1, :arg_type => :mandatory)
    another = Configuration.new('name', 1, :arg_type => :optional)
    assert config != another
    
    config = Configuration.new('name', 1, :reader => :reader)
    another = Configuration.new('name', 1, :reader => :alt)
    assert config != another
    
    config = Configuration.new('name', 1, :writer => :writer=)
    another = Configuration.new('name', 1, :writer => :alt=)
    assert config != another
  end
end
