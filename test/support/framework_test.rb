require  File.join(File.dirname(__FILE__), '../tap_test_helper')

class FrameworkTest < Test::Unit::TestCase
  acts_as_tap_test

  # sample class repeatedly used in tests
  class Sample
    include Tap::Support::Framework

    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  end

  #
  # include test
  #

  def test_include_extends_class_with_related_methods
    assert Sample.kind_of?(Tap::Support::BatchableMethods)
    assert Sample.kind_of?(Tap::Support::ConfigurableMethods)
    assert Sample.kind_of?(Tap::Support::FrameworkMethods)
  end
  
  #
  # source_file test
  #

  def test_source_file_is_set_to_file_first_including_Framework_in_class
    assert_equal File.expand_path(__FILE__), Sample.source_file
  end
  
  class SampleSubclass < Sample
  end
  
  def test_source_file_is_set_to_file_where_subclass_first_inherits_Framework
    assert_equal File.expand_path(__FILE__), SampleSubclass.source_file
  end

  #
  # initialize test
  #
  
  def test_app_is_initialized_to_App_instance_by_default
    assert_equal Tap::App.instance, Sample.new.app
  end

  def test_name_is_initialized_to_class_default_name_unless_specified
    assert_equal Sample.default_name, Sample.new.name
    assert_equal "alt", Sample.new("alt").name
  end
  
  class MockApp
    def initialize(templates)
      @templates = templates
    end
    
    def config_filepath(name)
      name
    end
    
    def each_config_template(config_file)
      (@templates[config_file] || []).each do |config|
        yield(config)
      end
    end
  end

  def test_batch_tasks_are_initialized_for_each_config_template_in_app
    app = MockApp.new 'name' => [{:one => 'ONE'}, {:two => 'TWO'}]
    
    t = Sample.new "name", {}, app
    assert_equal 2, t.batch.length
    
    assert_equal([
      {:one => 'ONE', :two => 'two', :three => 'three'},
      {:one => 'one', :two => 'TWO', :three => 'three'}],
      t.batch.collect {|task| task.config })
  end
  
  def test_initial_configs_override_file_configs
    app = MockApp.new 'name' => [{:one => 'ONE'}, {:two => 'TWO'}]
    
    t = Sample.new "name", {:one => 1, :three => 'THREE'}, app
    assert_equal 2, t.batch.length
    
    assert_equal([
      {:one => 1, :two => 'two', :three => 'THREE'},
      {:one => 1, :two => 'TWO', :three => 'THREE'}],
      t.batch.collect {|task| task.config })
  end
  
  #
  # config_file test
  #

  def test_config_file_is_app_config_filepath_when_config_file_exists
    t = Sample.new "configured"
    app_config_filepath = app.config_filepath("configured")

    assert_equal File.join(t.app['config'], "configured.yml"), app_config_filepath
    assert File.exists?(app_config_filepath)
    assert_equal app.config_filepath("configured"), t.config_file
  end

  def test_config_file_is_nil_for_nil_input_names
    t = Sample.new 
    assert_equal nil, t.config_file

    t = Sample.new nil
    assert_equal nil, t.config_file
  end

  #
  # initialize_batch_obj test
  #

  def test_initialize_batch_obj_merges_default_config_and_overrides
    t = Sample.new "configured", :three => 3
    assert_equal({
      :one => Tap::Support::Configuration.new(:one, 'one'), 
      :two => Tap::Support::Configuration.new(:two, 'two'), 
      :three => Tap::Support::Configuration.new(:three, 'three')
    }, t.class.configurations.map)
    assert_equal({:one => 'one', :two => 'TWO', :three => 3}, t.config)

    t1 = t.initialize_batch_obj
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, t1.config)  

    t2 = t.initialize_batch_obj(nil, {:three => 3})
    assert_equal({:one => 'one', :two => 'two', :three => 3}, t2.config)
  end
  
end
