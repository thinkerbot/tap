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
    assert Sample.kind_of?(Tap::Support::BatchableClass)
    assert Sample.kind_of?(Tap::Support::ConfigurableClass)
    assert Sample.kind_of?(Tap::Support::FrameworkClass)
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
  
  #
  # name test
  #
  
  def test_name_is_returns_class_default_name_unless_specified
    s = Sample.new
    assert_equal Sample.default_name, s.name
    
    s.name = "alt"
    assert_equal "alt", s.name
  end
  
  #
  # initialize_batch_obj test
  #

  def test_initialize_batch_obj_renames_batch_object_if_specified
    s = Sample.new
    s1 = s.initialize_batch_obj({}, 'new_name')
    assert_equal "new_name", s1.name
  end

  def test_initialize_batch_obj_reconfigures_batch_obj_with_overrides
    t = Sample.new :three => 3
    assert_equal({:one => 'one', :two => 'two', :three => 3}, t.config)

    t1 = t.initialize_batch_obj
    assert_equal({:one => 'one', :two => 'two', :three => 3}, t1.config)  

    t2 = t.initialize_batch_obj(:one => 'ONE')
    assert_equal({:one => 'ONE', :two => 'two', :three => 3}, t2.config)
  end
 
  #
  # to_s test
  #
  
  def test_to_s_returns_name
    s = Sample.new
    assert_equal s.name, s.to_s
    s.name = "alt_name"
    assert_equal "alt_name", s.to_s
  end
  
  def test_to_s_stringifies_name
    s = Sample.new({}, :name)
    assert_equal :name, s.name
    assert_equal 'name', s.to_s
  end
  
end
