require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/task/task_generator'
require 'tap/generator/preview.rb'

class TaskGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators

  def setup
    Tap::App.instance = Tap::App.new
  end
  
  #
  # process test
  #
  
  def test_task_generator
    t = TaskGenerator.new.extend Preview
    
    assert_equal %w{
      lib
      lib/const_name.rb
      test
      test/const_name_test.rb
    }, t.process('const_name')
  end
  
end