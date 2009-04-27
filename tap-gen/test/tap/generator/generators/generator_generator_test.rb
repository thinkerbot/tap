require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/generator'
require 'tap/generator/preview.rb'

class GeneratorGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  acts_as_tap_test
  
  #
  # process test
  #
  
  def test_generator_generator
    g = Generator.new.extend Preview
    
    assert_equal %w{
      lib/const_name
      lib/const_name/const_name_generator.rb
      templates/const_name
      templates/const_name/template_file.erb
      test
      test/const_name_generator_test.rb
    }, g.process('const_name')
    
    assert !GeneratorGeneratorTest.const_defined?(:ConstNameGenerator)
    eval(g.preview['lib/const_name/const_name_generator.rb'])
    
    method_root.prepare(:tmp, 'template_file.erb') do |file|
      file << g.preview['templates/const_name/template_file.erb']
    end
    
    c = ConstName.new.extend Preview
    c.template_dir = method_root[:tmp]
    
    assert_equal %w{
      const_name_file.txt
    }, c.process

    assert_equal %q{
# A sample template file.
key: value
}, "\n" + c.preview['const_name_file.txt']
  end
end