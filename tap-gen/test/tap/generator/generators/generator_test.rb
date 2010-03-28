require File.expand_path('../../../../tap_test_helper.rb', __FILE__) 
require 'tap/generator/generators/generator'
require 'tap/generator/preview.rb'

class GeneratorGeneratorTest < Test::Unit::TestCase
  Preview = Tap::Generator::Preview
  Generator = Tap::Generator::Generators::Generator

  acts_as_tap_test
  
  #
  # process test
  #
  
  def test_generator_generator
    g = Generator.new.extend Preview
    
    assert_equal %w{
      lib
      lib/const_name.rb
      test
      test/const_name_test.rb
      templates/const_name
      templates/const_name/template_file.erb
    }, g.process('const_name')
    
    assert !GeneratorGeneratorTest.const_defined?(:ConstNameGenerator)
    eval(g.preview['lib/const_name.rb'])
    
    method_root.prepare('template_file.erb') do |file|
      file << g.preview['templates/const_name/template_file.erb']
    end
    
    c = ConstName.new(:template_root => method_root).extend Preview
    
    assert_equal %w{
      const_name_file.txt
    }, c.process

    assert_equal %q{
# A sample template file.
key: value
}, "\n" + c.preview['const_name_file.txt']
  end
end