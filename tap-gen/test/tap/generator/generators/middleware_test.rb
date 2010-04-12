require File.join(File.dirname(__FILE__), '../../../tap_test_helper.rb') 
require 'tap/generator/generators/middleware'
require 'tap/generator/preview.rb'

class MiddlewareGeneratorTest < Test::Unit::TestCase
  Preview = Tap::Generator::Preview
  Middleware = Tap::Generator::Generators::Middleware
  
  acts_as_tap_test 
  
  def test_middleware_generator
    m = Middleware.new.extend Preview
    
    assert_equal %w{
      lib
      lib/const_name.rb
      test
      test/const_name_test.rb
    }, m.process('const_name')
    
    assert !MiddlewareGeneratorTest.const_defined?(:ConstName)
    eval(m.preview['lib/const_name.rb'])

    runlist = []
    n = lambda {|input| runlist << input}
    m = app.use(ConstName)
    
    assert_equal m, app.stack
    
    m.call(n, 'input')
    assert_equal ['input'], runlist
  end
end