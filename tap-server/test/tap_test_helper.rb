# setup testing with submodules
begin
  require 'tap/test'
rescue(LoadError)
  puts %Q{
Tests probably cannot be run because the submodules have
not been initialized.  Use these commands and try again:

  % git submodule init
  % git submodule update

}
  raise
end

# for rack
require 'rubygems'

TEST_ROOT = File.expand_path("#{File.dirname(__FILE__)}/../")
controllers_dir = TEST_ROOT + "/controllers"
$:.unshift controllers_dir unless $:.include?(controllers_dir)