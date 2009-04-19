require File.join(File.dirname(__FILE__), '../../tap_test_helper.rb')
require 'tap/generator/manifest'

class Tap::Generator::ManifestTest < Test::Unit::TestCase
  
  attr_reader :m, :actions
  
  def setup
    @actions = []
    @m = Tap::Generator::Manifest.new(actions)
  end
  
  #
  # method_missing test
  #
  
  def test_manifest_records_missing_method_calls_to_actions
    assert !m.respond_to?(:file)
    assert !m.respond_to?(:directory)
    assert_equal [], actions
    
    block = lambda {}
    m.file(:one, 2, 'three')
    m.directory(&block)
    
    assert_equal [
      [:file, [:one, 2, 'three'], nil],
      [:directory, [], block]
    ], actions
  end
end