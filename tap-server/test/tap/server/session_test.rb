require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/session'

class SessionTest < Test::Unit::TestCase
  acts_as_tap_test
  cleanup_dirs << :lib << :log
  
end