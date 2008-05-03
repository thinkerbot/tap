require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/templater'

class TemplaterTest < Test::Unit::TestCase
  include Tap::Support
  
  def test_build_formats_erb_with_existing_attributes
    t = Templater.new %Q{key: <%= attr %>}, {:attr => 'value'}
    assert_equal "key: value", t.build
  end
end