require File.expand_path('../../../../tap_test_helper.rb', __FILE__) 
require 'tap/generator/generators/tap'
require 'tap/generator/preview.rb'
require 'tap/version'
require 'rbconfig'

class TapTest < Test::Unit::TestCase
  include Tap::Generator
  include Generators
  acts_as_tap_test
  acts_as_shell_test
  
  #
  # process test
  #
  
  def test_tap_generator
    t = Tap.new.extend Preview
    
    assert_equal %w{
      tap
      profile.sh
    }, t.process
    
    tap = Tempfile.new('tap.rb')
    tap << t.preview['tap'] 
    tap.close
    
    sh_match %Q{ruby '#{tap.path}' -d- 2>&1},
      /ruby: #{RbConfig::CONFIG['RUBY_INSTALL_NAME']}-#{RUBY_VERSION} \(#{RUBY_RELEASE_DATE}\)/m,
      /tap: #{::Tap::VERSION}/m
  end
end