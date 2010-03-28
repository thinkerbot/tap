require File.expand_path('../../tap_test_helper.rb', __FILE__) 

class ReadmeTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test(SH_TEST_OPTIONS)
  
  def test_readme
      sh_test %Q{
% tap load/yaml "{key: value}" -: inspect
{"key"=>"value"}
}
  end
end