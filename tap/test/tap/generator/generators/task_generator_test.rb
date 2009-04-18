require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/task/task_generator'
require 'tap/generator/preview.rb'

class TaskGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  include AppInstance
  
  #
  # process test
  #
  
  def test_task_generator
    t = TaskGenerator.new.extend Preview
    
    assert_equal %w{
      lib
      lib/task_const_name.rb
      test
      test/task_const_name_test.rb
    }, t.process('task_const_name')
    
    assert !TaskGeneratorTest.const_defined?(:TaskConstName)
    eval(t.preview['lib/task_const_name.rb'])

    assert_equal "goodnight moon", TaskConstName.new.process('moon')
    assert_equal "hello world", TaskConstName.new(:message => 'hello').process('world')
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
    eval(t.preview['lib/nested/const.rb'])
    
    assert_equal "goodnight moon", Nested::Const.new.process('moon')
  end
  
end