require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/declarations'

class RapTutorialTest < Test::Unit::TestCase
  include Tap::Declarations
  
  def setup
    @declaration_base = "RapTutorialTest"
    @env = Tap::Env.new(:load_paths => [], :command_paths => [], :generator_paths => [])
  end
  
  def test_rap_documentation
    str = ""
    task(:a) { str << 'a' }

    namespace :b do
      a = task(:a) { str << 'b' }
    end

    c = task(:c => ['a', 'b:a'])
    task(:c) { str << 'c' }
    task(:c) { str << '!' }

    c.execute                      
    assert_equal 'abc!', str

    assert_equal C, c.class
    assert c == C.instance
    assert_equal Tap::Declarations::DeclarationTask, C.superclass

  end
end