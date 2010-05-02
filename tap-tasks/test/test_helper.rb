require 'tap/test/unit'

unless Object.const_defined?(:SH_TEST_OPTIONS)
  tap_root = File.expand_path('../../..', __FILE__)
  load_paths = [
    "-I'#{tap_root}/configurable/lib'",
    "-I'#{tap_root}/lazydoc/lib'",
    "-I'#{tap_root}/tap/lib'"
  ]
  
  SH_TEST_OPTIONS = {
    :cmd_pattern => '% tap',
    :cmd => (["ruby", "2>&1"] + load_paths + ["'#{tap_root}/tap/bin/tapexe'"]).join(" "),
    :env => {'TAP_PATH' => "#{tap_root}/tap:#{tap_root}/tap-tasks"}
  } 
end 