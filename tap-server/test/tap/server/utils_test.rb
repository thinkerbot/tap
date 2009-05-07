require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/server/utils'

class Tap::Server::UtilsTest < Test::Unit::TestCase
  include Tap::Server::Utils
  
  #
  # random_key test
  #
  
  def test_random_key_returns_integer
    assert random_key.kind_of?(Integer)
  end
end