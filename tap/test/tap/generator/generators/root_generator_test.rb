require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/root/root_generator'
require 'tap/generator/preview.rb'

class RootGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  
  def setup
    Tap::App.instance = Tap::App.new
  end
  
  #
  # process test
  #
  
  def test_root_generator
    g = RootGenerator.new.extend Preview
    
    assert_equal %w{
      .
      MIT-LICENSE
      README
      Rakefile
      lib
      project.gemspec
      tap.yml
      test
      test/tap_test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
    
    assert g.preview['tap.yml'].empty?
    assert g.preview['README'] =~ /MIT-LICENSE/
    assert g.preview['project.gemspec'] =~ /MIT-LICENSE/
  end
  
  def test_config_file_true_populates_tap_yml
    g = RootGenerator.new.extend Preview
    g.config_file = true
    
    assert_equal %w{
      .
      MIT-LICENSE
      README
      Rakefile
      lib
      project.gemspec
      tap.yml
      test
      test/tap_test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
    
    assert !g.preview['tap.yml'].empty?
  end
  
  def test_license_false_prevents_creation_of_license
    g = RootGenerator.new.extend Preview
    g.license = false
    
    assert_equal %w{
      .
      README
      Rakefile
      lib
      project.gemspec
      tap.yml
      test
      test/tap_test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
    
    assert g.preview['README'] !~ /MIT-LICENSE/
    assert g.preview['project.gemspec'] !~ /MIT-LICENSE/
  end
  
  def test_rapfile_true_creates_rapfile
    g = RootGenerator.new.extend Preview
    g.rapfile = true
    
    assert_equal %w{
      .
      MIT-LICENSE
      README
      Rakefile
      Rapfile
      lib
      project.gemspec
      tap.yml
      test
      test/tap_test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
  end
end