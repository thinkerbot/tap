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

unless Object.const_defined?(:SH_TEST_OPTIONS)
  root = File.expand_path("../..", __FILE__)
  SH_TEST_OPTIONS = {
    :cmd_pattern => "% tap", 
    :cmd => [
      "ruby",
      "-I'#{root}/../configurable/lib'",
      "-I'#{root}/../lazydoc/lib'",
      "-I'#{root}/lib'",
      "'#{root}/bin/tap'"
    ].join(" ")
  }
end
