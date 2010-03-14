require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/app'
require 'tap/test'

class ApiTest < Test::Unit::TestCase
  extend Tap::Test
  acts_as_tap_test
  
  Api = Tap::App::Api
  
  # ApiTest::Example::example desc is set to access this string
  class Example < Api
  end
  
  # ApiTest::Subclass::example the subclass also is also an 'example'
  class Subclass < Example
  end
  
  # ApiTest::Alt::not_alt this is the description...
  # ApiTest::Alt::alt     and not this.
  class Alt < Api
    class << self
      undef_method :desc   # prevents warnings
      undef_method :desc=
    end
    
    @type = "not_alt"
    lazy_attr(:desc, @type)
  end
  
  def test_documentation
    assert_equal "example", Example.type
    assert_equal "desc is set to access this string", Example.desc.to_s
  
    assert_equal "example", Subclass.type
    assert_equal "the subclass also is also an 'example'", Subclass.desc.to_s
  
    assert_equal "not_alt", Alt.type
    assert_equal "this is the description...", Alt.desc.to_s
  end
  
  #
  # help test
  #
  
  def test_help_signal_lists_signals
    app.set 'var', Example.new
    list = app.call('obj' => 'var', 'sig' => 'help', 'args' => [])
    assert list =~ /\/help\s+# signals help/
  end
  
  def test_help_with_arg_lists_signal_help
    app.set 'var', Example.new
    help = app.call('obj' => 'var', 'sig' => 'help', 'args' => ['help'])
    assert help =~ /Help -- signals help/
    
    help = app.call('obj' => 'var', 'sig' => 'help', 'args' => {'sig' => 'help'})
    assert help =~ /Help -- signals help/
  end
end

