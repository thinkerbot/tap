require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/test/unit'
require 'tap/version'
require 'rbconfig'

class SetupTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  acts_as_subset_test
  include TapTestMethods

  def test_tap_sets_default_env_when_run_through_rubygems
    extended_test do
      gem_test do |gem_env|
        gem_env.keys.each {|key| gem_env[key] = nil if key =~ /^TAP/ }
        tap_path = method_root.path('gem/bin/tap')
        
        sh_test %Q{
          '#{tap_path}' -d- 2>&1
                  ruby: #{RbConfig::CONFIG['RUBY_INSTALL_NAME']}-#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})
                   tap: #{Tap::VERSION}
                  gems: .
              generate: tap-#{Tap::VERSION}
                  path: .
                tapenv: tapenv
                 taprc: ~/.taprc:taprc
               tapfile: tapfile
        }, :env => gem_env
      end
    end
  end
end