require File.join(File.dirname(__FILE__), '../tap_test_helper')

class ReadmeTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  
  RAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
  LOAD_PATHS = [
    "-I'#{RAP_ROOT}/../configurable/lib'",
    "-I'#{RAP_ROOT}/../lazydoc/lib'",
    "-I'#{RAP_ROOT}/../tap/lib'"
  ]
  
  CMD_PATTERN = "% tap"
  CMD = (["TAP_GEMS= ruby"] + LOAD_PATHS + ["'#{RAP_ROOT}/../tap/bin/tap'"]).join(" ")
  
  def test_readme
      sh_test %Q{
% tap run -- load/yaml "{key: value}" --: inspect
{"key"=>"value"}
}
  end
end