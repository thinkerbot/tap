require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/task/task_generator'
require 'tap/generator/preview.rb'

class TaskGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  
  acts_as_tap_test
  
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
    
    assert !TaskGeneratorTest.const_defined?(:ConstName)
    eval(t.builds['lib/const_name.rb'])

    assert_equal "goodnight moon", ConstName.new.process('moon')
    assert_equal "hello world", ConstName.new(:message => 'hello').process('world')
  end
  
  def test_task_generator_does_not_generate_test_if_test_is_false
    t = TaskGenerator.new.extend Preview
    t.test = false
    
    assert_equal %w{
      lib
      lib/const_name.rb
    }, t.process('const_name')
  end
  
  def test_task_generator_nests_constants
    t = TaskGenerator.new.extend Preview
    
    assert_equal %w{
      lib/nested
      lib/nested/const.rb
      test/nested
      test/nested/const_test.rb
    }, t.process('nested/const')
    
    assert !TaskGeneratorTest.const_defined?(:Nested)
    eval(t.builds['lib/nested/const.rb'])
    
    assert_equal "goodnight moon", Nested::Const.new.process('moon')
  end
  
end