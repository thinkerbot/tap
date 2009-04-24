require File.join(File.dirname(__FILE__), '../rap_test_helper')
require 'rap/declarations'

class RapTutorialTest < Test::Unit::TestCase
  include Rap::Declarations
  
  def setup
    @declaration_base = "RapTutorialTest"
    @env = Tap::Env.new(:load_paths => [], :command_paths => [], :generator_paths => [])
    @app = Rap::Declarations.app = Tap::App.new
    
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
    assert c == C.instance(@app)
    assert_equal Rap::DeclarationTask, C.superclass
  end
end