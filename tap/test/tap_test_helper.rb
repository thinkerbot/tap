require 'test/unit'

begin
  require 'lazydoc'
  require 'configurable'
rescue(LoadError)
  puts %Q{
Tests probably cannot be run because the submodules have
not been initialized. Use these commands and try again:
 
% git submodule init
% git submodule update
 
}
  raise
end

unless Object.const_defined?(:TAP_ROOT)
  TAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/..")
end

unless Object.const_defined?(:RUBY_EXE)
  RUBY_EXE = "ruby"
end
