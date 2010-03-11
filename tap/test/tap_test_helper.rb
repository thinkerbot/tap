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

# a couple fixture constants...

module ConstName
end

module Nest
  module ConstName
  end
end

unless Object.const_defined?(:TAP_ROOT)
  TAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/..")
end

unless Object.const_defined?(:RUBY_EXE)
  RUBY_EXE = "ruby"
end

unless Object.const_defined?(:SH_TEST_OPTIONS)
  SH_TEST_OPTIONS = {
    :cmd_pattern => "% tap", 
    :cmd => [
      RUBY_EXE,
      "-I'#{TAP_ROOT}/../configurable/lib'",
      "-I'#{TAP_ROOT}/../lazydoc/lib'",
      "-I'#{TAP_ROOT}/lib'",
      "'#{TAP_ROOT}/bin/tap'"
    ].join(" "),
    :env => {
      'TAP_GEMS' => ''
    }
  }
end
