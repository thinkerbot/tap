require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/server'

class ServerUtilsTest < Test::Unit::TestCase
  include Tap::Server::Utils
  
  # acts_as_file_test
  # 
  # def setup
  #   @env = Tap::Env.new method_root
  # end
  
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
  
  #
  # cgi_attrs test
  #
  
  def test_cgi_attrs_splits_rack_env_based_on_rack_prefix
    assert_equal({
      :cgi => {'key' => 'value'},
      :rack => {'rack.key' => 'value'}
    }, cgi_attrs({'key' => 'value', 'rack.key' => 'value'}))
  end
  
  #
  # with_ENV test
  #
  
  def test_with_ENV_sets_ENV_for_the_duration_of_the_block
    current = ENV.to_hash
    begin
      ENV.clear
      ENV['key'] = 'value'
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
      was_in_block = false
      with_ENV('key' => 'alt', 'another' => 'value') do
        assert_equal({'key' => 'alt', 'another' => 'value'}, ENV.to_hash)
        was_in_block = true
      end
      assert was_in_block
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
    ensure
      ENV.clear
      current.each_pair {|key, value| ENV[key] = value }
    end
  end
  
  def test_with_ENV_skips_non_string_values
    current = ENV.to_hash
    begin
      ENV.clear
      ENV['key'] = 'value'
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
      was_in_block = false
      with_ENV('key' => 'alt', 'integer' => 1) do
        assert_equal({'key' => 'alt'}, ENV.to_hash)
        was_in_block = true
      end
      assert was_in_block
      assert_equal({'key' => 'value'}, ENV.to_hash)
      
    ensure
      ENV.clear
      current.each_pair {|key, value| ENV[key] = value }
    end
  end
end
