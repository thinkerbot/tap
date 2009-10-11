require File.join(File.dirname(__FILE__), '../rap_test_helper')

class TaskDocTest < Test::Unit::TestCase
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
  
  def test_build_doc
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
Rap.task(:a, :obj) {|t, a| puts "A #{a.obj}"}
Rap.task({:b => :a}, :obj) {|t, a| puts "B #{a.obj}"}
}
    end

    method_root.chdir(:tmp) do
      sh_test %q{
% rap b world -- a hello
A hello
B world
}
    end
  end
  
  def test_inclusion_of_task_doc
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
class Subclass < Rap::Task
  def helper(); "help"; end
end

# :: a help task
Subclass.task(:help) {|task, args| puts "got #{task.helper}"}
}
    end

    method_root.chdir(:tmp) do
      sh_test %q{
% rap help
got help
}
    end
  end
end