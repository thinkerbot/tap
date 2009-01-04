require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/task/task_generator'
require 'tap/test/generator_test.rb'

class TaskGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  include Tap::Test::GeneratorTest
  
  attr_reader :m, :actions
  
  def setup
    super
    @actions = []
    @m = Manifest.new(@actions)
  end
  
  #
  # manifest test
  #
  
  def test_task_generator_manifest
    g = TaskGenerator.new
    g.manifest(m, 'const_name')
    
    assert_actions [
      [:directory, "lib"], 
      [:template, "lib/const_name.rb"],
      [:directory, "test"], 
      [:template, "test/const_name_test.rb"]
    ], actions
  end
  
end