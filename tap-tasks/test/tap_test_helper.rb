begin
  require 'tap/test/unit'
rescue(LoadError)
  puts %Q{
Tests probably cannot be run because the submodules have
not been initialized.  Use these commands and try again:

  % git submodule init
  % git submodule update

}
  raise
end

unless Object.const_defined?(:SH_TEST_OPTIONS)
  tap_root = File.expand_path(File.dirname(__FILE__) + "/..")
  load_paths = [
    "-I'#{tap_root}/../configurable/lib'",
    "-I'#{tap_root}/../lazydoc/lib'",
    "-I'#{tap_root}/../tap/lib'"
  ]
  
  SH_TEST_OPTIONS = {
    :cmd_pattern => '% tap',
    :cmd => (["ruby", "2>&1"] + load_paths + ["'#{tap_root}/../tap/bin/tap'"]).join(" ")
  } 
end 