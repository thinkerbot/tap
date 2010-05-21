require 'tap/test/unit'

unless Object.const_defined?(:TEST_ROOT)
  TEST_ROOT = File.expand_path("#{File.dirname(__FILE__)}/../")
  controllers_dir = TEST_ROOT + "/controllers"
  $:.unshift controllers_dir unless $:.include?(controllers_dir)
end