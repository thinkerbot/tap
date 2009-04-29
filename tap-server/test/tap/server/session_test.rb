require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/server/session'

class SessionTest < Test::Unit::TestCase
  Session = Tap::Server::Session
  
  acts_as_file_test
  
  #
  # initialize test
  #
  
  def test_initialize
    s = Session.new
    assert_equal Tap::App, s.app.class
    assert_equal Tap::Server::Persistence, s.persistence.class
    assert_equal Dir.pwd, s.persistence.root
  end
end