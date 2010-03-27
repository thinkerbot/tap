require File.join(File.dirname(__FILE__), '../../../tap_test_helper.rb') 
require 'tap/generator/generators/env'
require 'tap/generator/preview.rb'

class EnvTest < Test::Unit::TestCase

  # Preview fakes out a generator for testing
  Preview = Tap::Generator::Preview
  
  acts_as_tap_test 
  
  def test_env
    g = Tap::Generator::Generators::Env.new.extend Preview
    
    # check the files and directories
    assert_equal %w{
      tapenv
    }, g.process
  end
end