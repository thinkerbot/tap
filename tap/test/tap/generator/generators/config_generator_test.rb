require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/config/config_generator'
require 'tap/generator/preview.rb'

class ConfigGeneratorTest < Test::Unit::TestCase
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
  
  module MockTaskLookup
    def set_tasc(name, tasc)
      (@mock_configurations ||= {})[name] = tasc
    end
    
    def lookup(name)
      @mock_configurations[name]
    end
  end
  
  #
  # input arguments test
  #
  
  class ConfigName < Tap::Task
  end
  
  def test_config_name_sets_the_config_file_name
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('config_name', ConfigName)
    
    assert_equal %w{
      config
      config/config_generator_test/config_name.yml
    }, c.process('config_name')
    
    assert_equal %w{
      config
      config/alt_name.yml
    }, c.process('config_name', 'alt_name')
    
    assert_equal %w{
      config
      config/alt_name.alt_ext
    }, c.process('config_name', 'alt_name.alt_ext')
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
    
    #   
    config :empty_doc, 'value'  #   
  end
  
  def test_config_generator_generates_config_file_with_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('doc_sample', DocSample)
    
    assert_equal %w{
      config
      config/doc_sample.yml
    }, c.process('doc_sample', 'doc_sample')
    
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

empty_doc: value

}, "\n" + c.preview['config/doc_sample.yml']
  end
  
  def test_config_generator_omits_documentation_if_specified
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('doc_sample', DocSample)
    c.doc = false
    assert_equal %w{
      config
      config/doc_sample.yml
    }, c.process('doc_sample', 'doc_sample')

    assert_equal %q{
key: value
long_doc: value
long_trailer: value
leader_and_trailer: value
no_doc: value
empty_doc: value
}, "\n" + c.preview['config/doc_sample.yml']
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
  
  def test_non_nested_config_file_with_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('nested_doc_sample', NestedDocSample)

    assert_equal %w{
      config
      config/nested_doc_sample.yml
    }, c.process('nested_doc_sample', 'nested_doc_sample')
    
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

}, "\n" + c.preview['config/nested_doc_sample.yml']
  end

  def test_nested_config_files_with_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('nested_doc_sample', NestedDocSample)
    
    c.nest = true
    assert_equal %w{
      config
      config/nested_doc_sample.yml
      config/nested_doc_sample/nest.yml
      config/nested_doc_sample/long_nest.yml
      config/nested_doc_sample/long_trailer.yml
      config/nested_doc_sample/leader_and_trailer.yml
      config/nested_doc_sample/no_doc.yml
      config/nested_doc_sample/nest_with_new_configs.yml
    }, c.process('nested_doc_sample', 'nested_doc_sample')
    
    %w{
      config/nested_doc_sample.yml
      config/nested_doc_sample/nest.yml
      config/nested_doc_sample/long_nest.yml
      config/nested_doc_sample/long_trailer.yml
      config/nested_doc_sample/leader_and_trailer.yml
      config/nested_doc_sample/no_doc.yml
    }.each do |path|
      assert_equal %q{
# key documentation
key: value

}, "\n" + c.preview[path], path
    end
    
    assert_equal %q{
# key documentation
key: value

another: config

}, "\n" + c.preview['config/nested_doc_sample/nest_with_new_configs.yml']
  end
      
  def test_non_nested_config_file_without_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('nested_doc_sample', NestedDocSample)
    
    c.doc = false
    assert_equal %w{
      config
      config/nested_doc_sample.yml
    }, c.process('nested_doc_sample', 'nested_doc_sample')

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
}, "\n" + c.preview['config/nested_doc_sample.yml']
  end
  
  def test_nested_config_files_without_documentation
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('nested_doc_sample', NestedDocSample)

    c.nest = true
    c.doc = false
    assert_equal %w{
      config
      config/nested_doc_sample.yml
      config/nested_doc_sample/nest.yml
      config/nested_doc_sample/long_nest.yml
      config/nested_doc_sample/long_trailer.yml
      config/nested_doc_sample/leader_and_trailer.yml
      config/nested_doc_sample/no_doc.yml
      config/nested_doc_sample/nest_with_new_configs.yml
    }, c.process('nested_doc_sample', 'nested_doc_sample')

    %w{
      config/nested_doc_sample.yml
      config/nested_doc_sample/nest.yml
      config/nested_doc_sample/long_nest.yml
      config/nested_doc_sample/long_trailer.yml
      config/nested_doc_sample/leader_and_trailer.yml
      config/nested_doc_sample/no_doc.yml
    }.each do |path|
      assert_equal %q{
key: value
}, "\n" + c.preview[path], path
    end

    assert_equal %q{
key: value
another: config
}, "\n" + c.preview['config/nested_doc_sample/nest_with_new_configs.yml']
  end
  
  #
  # -[no]-blanks test
  #
  
  class NestedBlankSample < Tap::Task
  end
  
  class BlankSample < Tap::Task
    define :nest, NestedBlankSample
  end
  
  def test_empty_config_files_are_skipped_if_no_blanks_is_specified
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('nested_blank_sample', NestedBlankSample)

    c.blanks = false
    assert_equal %w{
      config
    }, c.process('nested_blank_sample')
  end
  
  def test_empty_nested_config_files_are_skipped_if_no_blanks_is_specified
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('blank_sample', BlankSample)

    c.nest = true
    c.blanks = false
    assert_equal %w{
      config
    }, c.process('blank_sample')
  end
  
  def test_empty_config_files_are_created_if_blanks_is_true
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('blank_sample', BlankSample)

    c.nest = true
    assert_equal %w{
      config
      config/blank_sample.yml
      config/blank_sample/nest.yml
    }, c.process('blank_sample', 'blank_sample')
    
    assert_equal "", c.preview['config/blank_sample.yml']
    assert_equal "", c.preview['config/blank_sample/nest.yml']
  end
  
  #
  # dump/load tests
  #
  
  VALUES = {
    :str => 'string',
    :int => 1,
    :float => 1.2,
    :nil => nil,
    :true => true,
    :false => false,
    :empty_hash => {},
    :hash => {:key => 'value', :hash => {:key => 'value'}},
    :empty_array => [],
    :array => [1,2,[3,4]]
  }
  
  class SampleValues < Tap::Task
    VALUES.each_pair {|key, value| config key, value}
  end
  
  class NestedSampleValues < Tap::Task
    VALUES.each_pair {|key, value| config key, value}
    define :nest, SampleValues
  end
  
  class DoubleNestedSampleValues < Tap::Task
    VALUES.each_pair {|key, value| config key, value}
    define :nest, NestedSampleValues
  end
  
  def nil_values
    nils = {}
    VALUES.keys.each {|key| nils[key] = nil}
    nils
  end
  
  def test_tasks_can_be_reconfigured_with_loaded_configs
    c = ConfigGenerator.new.extend Preview
    c.extend MockTaskLookup
    c.set_tasc('sample', DoubleNestedSampleValues)
    c.process('sample', 'sample')
    
    task_nil_config = nil_values.merge(:nest => nil_values.merge(:nest => nil_values))
    nil_config =      nil_values.merge(:nest => nil_values.merge(:nest => nil_values))
    loaded_config = VALUES.merge(:nest => VALUES.merge(:nest => VALUES))
    
    task = DoubleNestedSampleValues.new(task_nil_config)
    assert_equal(nil_config, task.config.to_hash)
    
    task.reconfigure(YAML.load(c.preview['config/sample.yml']))
    assert_equal(loaded_config, task.config.to_hash)
  end
  
  def test_tasks_load_nested_dump_configs
    c = ConfigGenerator.new.extend Generate
    c.extend MockTaskLookup
    c.destination_root = method_root[:tmp]
    expected_config_file = method_root.path(:tmp, 'config/sample.yml')
    
    c.set_tasc('sample', DoubleNestedSampleValues)
    c.nest = true
    c.process('sample', 'sample')
    
    assert File.exists?(expected_config_file)
    
    task_nil_config = nil_values.merge(:nest => nil_values.merge(:nest => nil_values))
    nil_config =      nil_values.merge(:nest => nil_values.merge(:nest => nil_values))
    loaded_config = VALUES.merge(:nest => VALUES.merge(:nest => VALUES))
    
    task = DoubleNestedSampleValues.new(task_nil_config)
    assert_equal(nil_config, task.config.to_hash)
    
    task.reconfigure(DoubleNestedSampleValues.load_config(expected_config_file))
    assert_equal(loaded_config, task.config.to_hash)
  end
end