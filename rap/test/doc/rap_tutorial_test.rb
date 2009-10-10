require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declarations'

class RapTutorialTest < Test::Unit::TestCase
  include Rap::Declarations
  
  def setup
    env = Tap::Env.new
    app = Tap::App.new(:env => env)
    Context.instance.app = app
    
    ('A'..'Z').each do |letter|    
      Object.send(:remove_const, letter) if Object.const_defined?(letter)
    end
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
    assert c == instance(C)
    assert_equal Rap::Task, C.superclass
  end
end