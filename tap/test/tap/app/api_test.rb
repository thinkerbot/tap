require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/app/api'

class ApiTest < Test::Unit::TestCase
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
end

