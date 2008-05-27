require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/support/manifest_spec'

class ManifestSpecTest < Test::Unit::TestCase
  include Tap::Support
  
  #
  # initialize test
  #
  
  def test_new_manifest_spec_defaults_are_based_on_name
    m = ManifestSpec.new("manifest/name")
    assert_equal "manifest/name", m.name
    assert_equal 'Manifest::Name', m.class_name
    assert_equal "manifest/name.rb", m.path
    assert_equal ['manifest/name'], m.alias
    
    assert_equal "lib", m.load_path
    assert_equal ['run', 'server'], m.flags
  end
  
  def test_attributes_can_be_specified_on_initialize
    m = ManifestSpec.new("name", 
      :class_name => "Class::Name",
      :path => 'some/path.rb',
      :load_path => 'alt',
      :alias => ["some", "alias"],
      :flags => ["flag"]
    )
    
    assert_equal "name", m.name
    assert_equal 'Class::Name', m.class_name
    assert_equal 'some/path.rb', m.path
    assert_equal ["some", "alias"], m.alias
    
    assert_equal 'alt', m.load_path
    assert_equal ["flag"], m.flags
  end
end