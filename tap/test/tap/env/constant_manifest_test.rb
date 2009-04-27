require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/constant_manifest'
require 'tap/env'
require 'tempfile'

class ConstantManifestTest < Test::Unit::TestCase
  Env = Tap::Env
  ConstantManifest = Tap::Env::ConstantManifest
  include MethodRoot
  
  attr_reader :env, :m
  
  def setup
    super
    @env = Env.new
    @m = ConstantManifest.new(env, :attr)
  end
  
  #
  # build test
  #
  
  def test_build_caches_all_constant_attributes_in_path
    path = method_root.prepare("implicit.rb") do |io|
      io << %q{
# A::one comment a one
# A::two comment a two
# ::one comment implicit one
# ::two comment implicit two
}
    end
    
    m = ConstantManifest.new(env, :attr) do |env|
      [["implicit.rb", path]]
    end

    assert_equal({}, m.cache)
    m.build

    assert_equal({
      "implicit.rb" => {
        "A" => {
          "one" => "comment a one",
          "two" => "comment a two" },
        "Implicit" => {
          "one" => "comment implicit one",
          "two" => "comment implicit two"}
      }
    }, m.cache)
  end

  def test_build_does_nothing_if_path_is_in_cache
    path = method_root.prepare("implicit.rb") do |io|
      io << "# A::one"
    end
    
    m = ConstantManifest.new(env, :attr) do |env|
      [[method_root.root, path]]
    end
    
    m.cache[path] = {}
    m.build
    assert_equal({}, m.cache[path])
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
    
    m = ConstantManifest.new(env, 'a')
    assert_equal ["A"], m.constants('path').collect {|c| c.const_name }
    
    m = ConstantManifest.new(env, 'b')
    assert_equal ["B"], m.constants('path').collect {|c| c.const_name }
    
    m = ConstantManifest.new(env, 'z')
    assert_equal ["A", "B"], m.constants('path').collect {|c| c.const_name }
    
    m = ConstantManifest.new(env, 'q')
    assert_equal [], m.constants('path').collect {|c| c.const_name }
    
    m = ConstantManifest.new(env, /[a-z]/)
    assert_equal ["A", "A", "B", "B"], m.constants('path').collect {|c| c.const_name }
  end
end