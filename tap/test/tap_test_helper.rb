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

module TestUtils
  module_function
  
  def match_platform?(*platforms)
    platforms.each do |platform|
      platform.to_s =~ /^(non_)?(.*)/

      non = true if $1
      match_platform = !RUBY_PLATFORM.index($2).nil?
      return false unless (non && !match_platform) || (!non && match_platform)
    end

    true
  end
end unless Object.const_defined?(:TestUtils)
