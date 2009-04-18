require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/constant_manifest'
require 'tempfile'

class ConstantManifestTest < Test::Unit::TestCase
  ConstantManifest = Tap::Env::ConstantManifest
  include MethodRoot
  
  attr_reader :m
  
  def setup
    super
    @m = ConstantManifest.new(:env, :attr)
  end
  
  #
  # scan test
  #

  def test_scan_caches_all_constant_attributes_in_path
    path = method_root.prepare("implicit.rb") do |io|
      io << %q{
# A::one comment a one
# A::two comment a two
# ::one comment implicit one
# ::two comment implicit two
}
    end
    
    assert_equal({}, m.cache)
    m.scan(method_root.root, path)
    
    assert_equal({
      path => {
        "A" => {
          "one" => "comment a one",
          "two" => "comment a two" },
        "Implicit" => {
          "one" => "comment implicit one",
          "two" => "comment implicit two"}
      }
    }, m.cache)
  end
  
  def test_scan_does_nothing_if_path_is_in_cache
    path = method_root.prepare("implicit.rb") do |io|
      io << "# A::one"
    end

    m.cache = {path => 1}
    m.scan(method_root.root, path)
    assert_equal({path => 1}, m.cache)
  end
  
  #
  # constants test
  #
  
  def test_constants_raises_error_if_path_is_not_in_cache
    assert m.cache.empty?
    
    err = assert_raises(RuntimeError) { m.constants('path.rb') }
    assert_equal "no scan for: path.rb", err.message
  end
  
  def test_constants_returns_cached_constants_along_path_case_matching_const_attr
    m.cache['path'] = {
      "A" => {"a" => "", "z" => ""},
      "B" => {"b" => "", "z" => ""}
    }
    
    m.const_attr = 'a'
    assert_equal ["A"], m.constants('path').collect {|c| c.const_name }
    
    m.const_attr = 'b'
    assert_equal ["B"], m.constants('path').collect {|c| c.const_name }
    
    m.const_attr = 'z'
    assert_equal ["A", "B"], m.constants('path').collect {|c| c.const_name }
    
    m.const_attr = 'q'
    assert_equal [], m.constants('path').collect {|c| c.const_name }
    
    m.const_attr = /[a-z]/
    assert_equal ["A", "A", "B", "B"], m.constants('path').collect {|c| c.const_name }
  end
end