require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/generator/generator_generator'
require 'tap/generator/preview.rb'

class GeneratorGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  
  attr_accessor :method_root
  
  def setup
    @method_root = Tap::Root.new("#{__FILE__.chomp(".rb")}_#{method_name}")
  end
  
  def teardown
    # clear out the output folder if it exists, unless flagged otherwise
    unless ENV["KEEP_OUTPUTS"]
      if File.exists?(method_root.root)
        FileUtils.rm_r(method_root.root)
      end
    end
  end
  
  #
  # process test
  #
  
  def test_generator_generator
    g = GeneratorGenerator.new.extend Preview
    
    assert_equal %w{
      lib/const_name
      lib/const_name/const_name_generator.rb
      lib/const_name/templates
      lib/const_name/templates/template_file.erb
      test
      test/const_name_generator_test.rb
    }, g.process('const_name')
    
    assert !GeneratorGeneratorTest.const_defined?(:ConstNameGenerator)
    eval(g.preview['lib/const_name/const_name_generator.rb'])
    
    method_root.prepare(:tmp, 'template_file.erb') do |file|
      file << g.preview['lib/const_name/templates/template_file.erb']
    end
    
    c = ConstNameGenerator.new.extend Preview
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