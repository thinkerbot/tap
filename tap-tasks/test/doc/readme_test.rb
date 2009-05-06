require File.join(File.dirname(__FILE__), '../tap_test_helper')

class ReadmeTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test(SH_TEST_OPTIONS)
  
  def test_readme
      sh_test %Q{
% tap run -- load/yaml "{key: value}" --: inspect
{"key"=>"value"}
}
  end
end