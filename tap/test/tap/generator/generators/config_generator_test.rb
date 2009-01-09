require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/config/config_generator'
require 'tap/generator/preview.rb'

class ConfigGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  
  acts_as_tap_test
  
  module MockTaskLookup
    def set_configuration_for(name, configs)
      (@mock_configurations ||= {})[name] = configs
    end
    
    def configurations_for(name)
      @mock_configurations[name]
    end
  end
  
  #
  # process with/without documentation test
  #
  
  class DocSample < Tap::Task
    config :key, 'value' # key documentation
    
    # long long preceding key documentation that should span multiple lines and
    #
    #   show indentation
    #   as in code
    #
    # the end
    config :long_doc, 'value'        
    config :long_trailer, 'value' # a long long trailer that should span multiple lines
    
    # leader
    config :leader_and_trailer, 'value' # trailer
    
    config :no_doc, 'value'
  end
  
  def test_config_generator_generates_config_file_with_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_configuration_for('doc_sample', DocSample.configurations)
    
    assert_equal %w{
      config
      config/doc_sample.yml
    }, c.process('doc_sample')
    
    assert_equal %q{
# key documentation
key: value

# long long preceding key documentation that should
# span multiple lines and
# 
#   show indentation
#   as in code
# 
# the end
long_doc: value

# a long long trailer that should span multiple
# lines
long_trailer: value

# trailer
leader_and_trailer: value

no_doc: value

}, "\n" + c.builds['config/doc_sample.yml']
  end
  
  def test_config_generator_omits_documentation_if_specified
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_configuration_for('doc_sample', DocSample.configurations)
    c.doc = false
    assert_equal %w{
      config
      config/doc_sample.yml
    }, c.process('doc_sample')

    assert_equal %q{
key: value
long_doc: value
long_trailer: value
leader_and_trailer: value
no_doc: value
}, "\n" + c.builds['config/doc_sample.yml']
  end
  
  #
  # process nested with/without documentation test
  #
  
  class SimpleDocSample < Tap::Task
    config :key, 'value' # key documentation
  end
  
  class NestedDocSample < Tap::Task
    define :nest, SimpleDocSample # nest documentation
    
    # long long preceding nest documentation that should span multiple lines and
    #
    #   show indentation
    #   as in code
    #
    # the end
    define :long_nest, SimpleDocSample 
    define :long_trailer, SimpleDocSample # a long long trailer that should span multiple lines
    
    # leader
    define :leader_and_trailer, SimpleDocSample # trailer
    
    define :no_doc, SimpleDocSample
    
    define :nest_with_new_configs, SimpleDocSample, :another => 'config'
    
    config :key, 'value'             # key documentation
  end
  
  def test_nested_config_file_with_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_configuration_for('nested_doc_sample', NestedDocSample.configurations)

    assert_equal %w{
      config
      config/nested_doc_sample.yml
    }, c.process('nested_doc_sample')
    
    assert_equal %q{
# nest documentation
nest: 
  # key documentation
  key: value
  
# long long preceding nest documentation that should
# span multiple lines and
# 
#   show indentation
#   as in code
# 
# the end
long_nest: 
  # key documentation
  key: value
  
# a long long trailer that should span multiple
# lines
long_trailer: 
  # key documentation
  key: value
  
# trailer
leader_and_trailer: 
  # key documentation
  key: value
  
no_doc: 
  # key documentation
  key: value
  
nest_with_new_configs: 
  # key documentation
  key: value
  
  another: config
  
# key documentation
key: value

}, "\n" + c.builds['config/nested_doc_sample.yml']
  end
  
  def test_nested_config_file_without_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_configuration_for('nested_doc_sample', NestedDocSample.configurations)
    
    c.doc = false
    assert_equal %w{
      config
      config/nested_doc_sample.yml
    }, c.process('nested_doc_sample')

    assert_equal %q{
nest: 
  key: value
long_nest: 
  key: value
long_trailer: 
  key: value
leader_and_trailer: 
  key: value
no_doc: 
  key: value
nest_with_new_configs: 
  key: value
  another: config
key: value
}, "\n" + c.builds['config/nested_doc_sample.yml']
  end
end