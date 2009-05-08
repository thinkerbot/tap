require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/server/session'

class Tap::Server::SessionTest < Test::Unit::TestCase
  Session = Tap::Server::Session
  
  acts_as_tap_test
  acts_as_file_test
  
  attr_accessor :s
  
  def setup
    super
    @s = Session.new
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    s = Session.new
    assert_equal Tap::App.instance, s.app
    assert_equal Tap::Server::Persistence, s.persistence.class
    assert_equal Dir.pwd, s.persistence.root
  end
  
  #
  # attributes test
  #
  
  def test_attributes_has_nil_app_for_app_instance
    assert_equal Tap::App.instance, s.app
    assert_equal nil, s.attributes[:app]
  end
  
  #
  # app= test
  #
  
  def test_set_app_uses_input_app
    app = Tap::App.new
    s.app = app
    assert_equal app, s.app
  end
  
  def test_set_app_uses_App_instance_for_nil
    not_instance_app = Tap::App.new
    s.app = not_instance_app
    assert Tap::App.instance != s.app
    
    s.app = nil
    assert_equal Tap::App.instance, s.app
  end
  
  def test_set_app_initializes_new_app_for_hash
    assert_equal app, s.app
    
    s.app = {:debug => false}
    assert app.object_id != s.app.object_id 
    assert_equal false, s.app.debug
  end
  
end