require File.join(File.dirname(__FILE__), '../rap_test_helper')

class SyntaxTest < Test::Unit::TestCase 
  rap_root = File.expand_path(File.dirname(__FILE__) + "/../..")
  load_paths = [
    "-I'#{rap_root}/../configurable/lib'",
    "-I'#{rap_root}/../lazydoc/lib'",
    "-I'#{rap_root}/../tap/lib'"
  ]
  
  acts_as_file_test
  acts_as_shell_test(
    :cmd_pattern => "% rap",
    :cmd => (["ruby"] + load_paths + ["'#{rap_root}/bin/rap'"]).join(" "),
    :env => {'TAP_GEMS' => ''}
  )
  
  def test_namespace_lookup
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
include Rap::Declarations
task(:outer) { print 'non-nested' }
namespace :nest do
  task(:inner1 => :outer) { puts ' was executed' }
  task(:inner2 => 'nest:outer') { puts ' was executed' }
  task(:outer) { print 'nested' }
end
}
    end
    
    method_root.chdir(:tmp) do
      sh_test %Q{
% rap nest/inner1
non-nested was executed
}
     sh_test %Q{
% rap nest/inner2
nested was executed
}
#     sh_test %Q{
# % rake nest:inner1
# nested was executed
# }
#     sh_test %Q{
# % rake nest:inner2
# nested was executed
# }
    end
  end
end