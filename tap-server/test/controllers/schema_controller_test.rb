require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'schema_controller'

class SchemaControllerUtilsTest < Test::Unit::TestCase
  include SchemaController::Utils
  
  #
  # pair_parse test
  #
  
  def test_pair_parse_collects_ordinary_key_value_pairs
    assert_equal({'key' => ['value']}, pair_parse('key' => ['value']))
    assert_equal({'key' => ['a', 'b', 'c']}, pair_parse('key' => ['a', 'b', 'c']))
  end
  
  def test_pair_parse_parses_url_encoded_hashes
    assert_equal({'key' => {'key' => ['value']}}, pair_parse('key[key]' => ['value']))
  end
  
  def test_pair_parse_parses_url_encoded_arrays
    assert_equal({'key' => [['a', 'b', 'c']]}, pair_parse('key[]' => ['a', 'b', 'c']))
  end
  
  def test_pair_parse_shellword_splits_values_keyed_with_a_percent_sign_w
    assert_equal({'key' => ['a', 'b', 'c']}, pair_parse('key%w' => ['a b c']))
  end
  
  def test_pair_parse_concatenates_shellword_and_ordinary_values
    assert_equal ['a', 'b', 'c', 'value'].sort, pair_parse('key%w' => ['a b c'], 'key' => ['value'])['key'].sort
  end
  
  class MockIO
    def initialize(str)
      @str = str
    end
    def read
      @str
    end
  end
  
  def test_pair_parse_reads_values_that_may_be_read
    assert_equal({'key' => ['value']}, pair_parse('key' => [MockIO.new('value')]))
    assert_equal({'key' => ['a', 'b', 'c']}, pair_parse('key%w' => [MockIO.new('a b c')]))
  end
end

class SchemaControllerTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :views << :public

end
