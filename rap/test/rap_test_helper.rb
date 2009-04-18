# setup testing with submodules
begin
  require 'test/unit'
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

Test::Unit::TestCase.extend Tap::Test