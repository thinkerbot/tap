require File.join(File.dirname(__FILE__), '../../../tap_test_helper.rb') 
require 'tap/generator/generators/tap'
require 'tap/generator/preview.rb'

class TapTest < Test::Unit::TestCase

  # Preview fakes out a generator for testing
  Preview = Tap::Generator::Preview
  
  acts_as_tap_test 
  
  def test_tap
    g = Tap::Generator::Generators::Tap.new.extend Preview
    
    # check the files and directories
    assert_equal %w{
      tap/generator/generators/tap_file.txt
    }, g.process
    
    # check the content as necessary
    assert_equal %q{
# A sample template file.
key: value
}, "\n" + g.preview['tap/generator/generators/tap_file.txt']
  end
end