require File.expand_path('../../../../test_helper.rb', __FILE__) 
require 'tap/generator/generators/root'
require 'tap/generator/preview.rb'

class RootGeneratorTest < Test::Unit::TestCase
  Root = Tap::Generator::Generators::Root
  Preview = Tap::Generator::Preview
  acts_as_tap_test
  
  #
  # process test
  #
  
  def test_root_generator
    g = Root.new.extend Preview
    
    assert_equal %w{
      .
      History
      MIT-LICENSE
      README
      lib
      project.gemspec
      tap.yml
      tapfile
      test
      test/test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
    
    assert g.preview['README'] =~ /MIT-LICENSE/
    assert g.preview['project.gemspec'] =~ /MIT-LICENSE/
  end
  
  def test_env_true_populates_tap_yml
    g = Root.new.extend Preview
    g.env = true
    
    assert_equal %w{
      .
      History
      MIT-LICENSE
      README
      lib
      project.gemspec
      tap.yml
      tapfile
      test
      test/test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
  end
  
  def test_history_false_prevents_creation_of_History
    g = Root.new.extend Preview
    
    g.history = false
    assert_equal %w{
      .
      MIT-LICENSE
      README
      lib
      project.gemspec
      tap.yml
      tapfile
      test
      test/test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
  end
  
  def test_license_false_prevents_creation_of_license
    g = Root.new.extend Preview
    g.license = false
    
    assert_equal %w{
      .
      History
      README
      lib
      project.gemspec
      tap.yml
      tapfile
      test
      test/test_helper.rb
    }, g.process(Dir.pwd, 'project').sort
    
    assert g.preview['README'] !~ /MIT-LICENSE/
    assert g.preview['project.gemspec'] !~ /MIT-LICENSE/
  end
end

class RootHelperTest < Test::Unit::TestCase
  include Tap::Generator::Generators::Root::Helper
  
  def test_titleize
    assert_equal 'Project', titleize('project')
    assert_equal 'Pro-Ject', titleize('pro_ject')
    assert_equal 'Pro-Ject', titleize('pro-ject')
  end
end