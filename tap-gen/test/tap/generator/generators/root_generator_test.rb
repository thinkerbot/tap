require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/generator/generators/root/root_generator'
require 'stringio'

class RootGeneratorTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  
  acts_as_file_test
  
  attr_reader :m, :actions
  
  def setup
    super
    @actions = []
    @m = Manifest.new(@actions)
  end
  
  def build_file(block)
    return nil if block == nil
    io = StringIO.new("")
    block.call(io)
    io.string
  end
  
  def build_template(template_path, attributes)
    Tap::Support::Templater.new(File.read(template_path), attributes).build
  end
  
  def relative_path(root, path)
    Tap::Root.relative_filepath(root, path)
  end
  
  def assert_actions(expected, actual, root=Dir.pwd)
    assert_equal expected.length, actual.length, "unequal number of actions"
    
    index = 0
    actual.each do |action, args, block|
      expect_action, expect_path = expected[index]
      
      assert_equal expect_action, action
      assert_equal expect_path, relative_path(root, args[0])
      
      case action
      when :file
        yield(expect_path, build_file(block)) 
      when :template
        yield(expect_path, build_template(args[1], args[2]))
      end if block_given?
      
      index += 1
    end
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
      [:template, "test/tap_test_suite.rb"], 
      [:file, "tap.yml"]
    ], actions
  end
end