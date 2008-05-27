require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/manifest'

class ManifestTest < Test::Unit::TestCase
  include Tap::Support
  
  attr_reader :m
  def setup
    @m = Manifest.new
  end
  
  #
  # get test
  #
  
  def test_get_returns_stored_manifest
    spec = ManifestSpec.new('name', :class_name => "ClassName")
    m['name'] = spec
    assert_equal spec, m['name']
  end
  
  def test_get_initializes_new_manifest_spec_if_none_exists
    assert_equal ManifestSpec.new('name'), m['name']
  end
  
  #
  # set test
  #
  
  def test_set_stores_manifest_by_name
    spec = ManifestSpec.new('name', :class_name => "ClassName")
    m['name'] = spec
    
    assert_equal({'name' => spec}, m.to_hash)
  end
  
  def test_set_creates_manifest_with_value_as_class_name_when_value_is_String
    m['name'] = "ClassName"
    assert_equal({'name' => ManifestSpec.new('name', :class_name => "ClassName")}, m.to_hash)
  end
  
  def test_set_creates_manifest_with_name_and_value_as_attributes_when_value_is_Hash
    m['name'] = {:class_name => "ClassName"}
    assert_equal({'name' => ManifestSpec.new('name', :class_name => "ClassName")}, m.to_hash)
  end
  
end