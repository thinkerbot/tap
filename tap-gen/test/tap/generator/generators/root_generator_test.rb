require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/root/root_generator'
require 'tap/test/generator_test.rb'

class RootGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  include Tap::Test::GeneratorTest
  
  attr_reader :m, :actions
  
  def setup
    super
    @actions = []
    @m = Manifest.new(@actions)
  end
  
  #
  # manifest test
  #
  
  def test_root_generator_manifest
    g = RootGenerator.new
    g.manifest(m, Dir.pwd, 'project')
    
    assert_actions [
      [:directory, ""], 
      [:directory, "lib"], 
      [:directory, "test"], 
      [:template, "README"],
      [:template, "Rakefile"], 
      [:template, "project.gemspec"], 
      [:template, "test/tap_test_helper.rb"],
      [:file, "tap.yml"]
    ], actions
  end
  
  def test_config_file_false_prevents_creation_of_tap_yml
    g = RootGenerator.new
    g.config_file = false
    g.manifest(m, Dir.pwd, 'project')
    
    assert_actions [
      [:directory, ""], 
      [:directory, "lib"], 
      [:directory, "test"], 
      [:template, "README"],
      [:template, "Rakefile"], 
      [:template, "project.gemspec"], 
      [:template, "test/tap_test_helper.rb"]
    ], actions
  end
  
  def test_rapfile_true_creates_rapfile
    g = RootGenerator.new
    g.rapfile = true
    g.manifest(m, Dir.pwd, 'project')
    
    assert_actions [
      [:directory, ""], 
      [:directory, "lib"], 
      [:directory, "test"], 
      [:template, "README"],
      [:template, "Rakefile"], 
      [:template, "Rapfile"], 
      [:template, "project.gemspec"], 
      [:template, "test/tap_test_helper.rb"],
      [:file, "tap.yml"]
    ], actions
  end
end