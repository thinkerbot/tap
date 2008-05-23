require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class OptionTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :o
  def setup
    @o = Option.new('name')
  end
  
  #
  # Option.shortify test
  #
  
  def test_shortify_documentation
    assert_equal "-o", Option.shortify("-o")
    assert_equal "-o", Option.shortify(:o)
  end
  
  def test_shortify_formats_str_as_short_option
    assert_equal "-o", Option.shortify("-o")
    assert_equal "-O", Option.shortify("-O")
    
    assert_equal "-o", Option.shortify("o")
    assert_equal "-O", Option.shortify("O")
  end
  
  def test_shortify_stringifies_input
    assert_equal "-o", Option.shortify('-o'.to_sym)
    assert_equal "-o", Option.shortify(:o)
  end
  
  def test_shortify_raises_error_for_shorts_that_dont_match_SHORT_REGEXP
    assert_raise(RuntimeError) { Option.shortify("-1") }
    assert_raise(RuntimeError) { Option.shortify("1") }
    assert_raise(RuntimeError) { Option.shortify("bogus") }
    assert_raise(RuntimeError) { Option.shortify("#") }
    assert_raise(RuntimeError) { Option.shortify("-") }
    assert_raise(RuntimeError) { Option.shortify("") }
  end
  
  #
  # Option.longify test
  #
  
  def test_longify_documentation
    assert_equal "--opt", Option.longify("--opt")
    assert_equal "--opt", Option.longify(:opt)
    assert_equal "--[no-]opt", Option.longify(:opt, true)
    assert_equal "--opt-ion", Option.longify(:opt_ion)
    assert_equal "--opt_ion", Option.longify(:opt_ion, false, false)
  end
  
  def test_longify_formats_str_as_long_option
    assert_equal "--opt", Option.longify("--opt")
    assert_equal "--opt", Option.longify("opt")
  end
  
  def test_longify_stringifies_input
    assert_equal "--opt", Option.longify('--opt'.to_sym)
    assert_equal "--opt", Option.longify(:opt)
  end
  
  def test_longify_with_switch_format_adds_no_string_if_necessary
    assert_equal "--[no-]opt", Option.longify('opt', true)
    assert_equal "--[no-]opt", Option.longify('[no-]opt', true)
    assert_equal "--[no-]opt", Option.longify('--[no-]opt', true)
  end
  
  def test_longify_with_hyphenize_gsubs_underscore_for_hyphen
    assert_equal "--opt-ion", Option.longify('opt_ion', false, true)
  end
  
  def test_longify_raises_error_for_shorts_that_dont_match_LONG_REGEXP
    assert_raise(RuntimeError) { Option.longify("-0") }
    assert_raise(RuntimeError) { Option.longify("--0") }
    assert_raise(RuntimeError) { Option.longify("--[blah-]option") }
    assert_raise(RuntimeError) { Option.longify("--@!") }
    assert_raise(RuntimeError) { Option.longify("_option", false, true) }
    assert_raise(RuntimeError) { Option.longify("") }
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    o = Option.new('name')
    assert_equal 'name', o.name
    assert_nil o.default
    assert_equal({}, o.properties)
    
    o = Option.new('name', 'default', :arg => :optional)
    assert_equal 'name', o.name
    assert_equal 'default', o.default
    assert_equal({:arg => :optional}, o.properties)
  end
  
  #
  # default= test
  #
  
  def test_set_default_sets_default
    assert_nil o.default
    o.default = 1
    assert_equal 1, o.default
  end
  
  def test_set_default_sets_duplicable_to_false_if_default_cannot_be_duplicated
    [nil, 1, 1.1, true, false, :sym].each do |non_duplicable_default|
      o.default = non_duplicable_default
      assert !o.duplicable
    end
  end
  
  def test_set_default_sets_duplicable_to_true_if_default_can_be_duplicated
    [{}, [], Object.new].each do |duplicable_default|
      o.default = duplicable_default
      assert o.duplicable
    end
  end
  
  def test_set_default_freezes_object
    a = []
    assert !a.frozen?
    o.default = a
    assert a.frozen?
  end
  
  def test_non_freezable_objects_are_not_frozen
    o.default = 1
    assert !o.default.frozen?
    
    o.default = :sym
    assert !o.default.frozen?
    
    o.default = nil
    assert !o.default.frozen?
  end
  
  #
  # default test
  #

  def test_default_returns_default
    assert_equal nil, o.default
    
    o.default = 'value'
    assert_equal 'value', o.default
  end
  
  def test_default_returns_duplicate_values
    a = [1,2,3]
    o.default = a
  
    assert_equal a, o.default
    assert_not_equal a.object_id, o.default.object_id
  end
  
  def test_default_does_not_duplicate_if_specified
    a = [1,2,3]
    o.default = a
  
    assert_equal a, o.default(false)
    assert_equal a.object_id, o.default(false).object_id
  end
  
  #
  # to_option_parser_argv test
  #
  
  #
  # == test
  #
  
  def test_another_is_equal_to_self_if_all_attributes_are_equal
    option = Option.new('name')
    another = Option.new('name')
    assert option == another
    
    option = Option.new('name')
    another = Option.new('alt')
    assert option != another
    
    option = Option.new('name', 1)
    another = Option.new('name', 2)
    assert option != another
    
    option = Option.new('name', 1, :mandatory)
    another = Option.new('name', 1, :optional)
    assert option != another
  end
  
end