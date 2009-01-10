require File.join(File.dirname(__FILE__), '../rap_test_helper')

class RapTest < Test::Unit::TestCase
  acts_as_script_test
  cleanup_dirs << :root
  
  RAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/rap")
  LOAD_PATHS = $:.collect {|path| "-I'#{File.expand_path(path)}'"}.uniq.join(' ')
  
  def setup
    super
    method_root.prepare('tap.yml') {}
    method_root.prepare('Rakefile') {}
  end

  def default_command_path
    %Q{ruby #{LOAD_PATHS} "#{RAP_EXECUTABLE_PATH}"}
  end

  def test_rap_help_with_no_declarations
    script_test do |cmd|
      cmd.check "Prints help and summary for rap", %Q{
% #{cmd}
usage: rap taskname {options} [args]

===  tap tasks ===
  dump        # the default dump task
  load        # the default load task

=== rake tasks ===
:...:
% #{cmd} -T
usage: rap taskname {options} [args]

===  tap tasks ===
  dump        # the default dump task
  load        # the default load task

=== rake tasks ===
:...:
}
    end
  end
  
  def test_rap_help_with_declarations
    method_root.prepare('Tapfile') do |file|
      file << %q{
include Rap::Declarations
  
namespace :rap_test do
  # ::desc task summary
  # long description
  task :task_with_doc
  
  task :task_without_doc
  
  desc "desc"
  task :task_with_desc
end
}
    end
    
    script_test do |cmd|
      cmd.check "Prints summary of declarations", %Q{
% #{cmd}
usage: rap taskname {options} [args]

===  tap tasks ===
test_rap_help_with_declarations:
  task_with_doc     # task summary
  task_with_desc    # desc
tap:
  dump              # the default dump task
  load              # the default load task

=== rake tasks ===
:...:
}

      cmd.check "Prints help for declaration", %Q{
% #{cmd} task_with_doc --help
RapTest::TaskWithDoc -- task summary
--------------------------------------------------------------------------------
  long description
--------------------------------------------------------------------------------
usage: rap rap_test/task_with_doc 
:...:
% #{cmd} task_without_doc --help
RapTest::TaskWithoutDoc

usage: rap rap_test/task_without_doc 
:...:
% #{cmd} task_with_desc --help
RapTest::TaskWithDesc -- desc

usage: rap rap_test/task_with_desc 
:...:}
    end
  end
    
  def test_rap_help_with_duplicate_nested_declarations
    method_root.prepare('Tapfile') do |file|
      file << %q{
include Rap::Declarations

desc "first desc"
task :task

namespace :sample do
  desc "first desc"
  task :task

  desc "second desc"
  task :task
end
}
    end

    script_test do |cmd|
      cmd.check "Prints proper description", %Q{
% #{cmd}
:...:
test_rap_help_with_duplicate_nested_declarations:
  task         # first desc
  sample/task  # second desc
:...:
}
    end
  end
      
  def test_rap_help_for_tasks_with_args
    method_root.prepare('Tapfile') do |file|
      file << %q{
include Rap::Declarations
namespace :RapTest do

  task(:task_without_args) {}
  task(:task_with_args) {|task, args|}
  
  task(:task_without_arg_names, :a, :b)
  task(:task_with_arg_names, :a, :b) 
end
}
    end

    script_test do |cmd|
      cmd.check "Prints help for declaration", %Q{
% #{cmd} task_without_args --help
:...:
usage: rap rap_test/task_without_args 
:...:
% #{cmd} task_with_args --help
:...:
usage: rap rap_test/task_with_args 
:...:
% #{cmd} task_without_arg_names --help
:...:
usage: rap rap_test/task_without_arg_names A B
:...:
% #{cmd} task_with_arg_names --help
:...:
usage: rap rap_test/task_with_arg_names A B
:...:
}
    end
  end
  
  def test_rap_uses_rap_and_tapfiles
    [ 
    ['Tapfile'],
    ['rapfile.rb'],
    ['tapfile.rb', 'Rapfile']].each do |paths|
      Tap::Test::Utils.clear_dir(method_root.root)
      method_root.prepare('tap.yml') {}
      
      manifests = []
      paths.each do |path|
        basename = File.basename(path).chomp('.rb').underscore
        method_root.prepare(path) do |file|
          manifests << "  task_#{basename}  # #{path}"
          file << %Q{
include Rap::Declarations

desc "#{path}"
task(:task_#{basename})
}
        end
      end
      
      script_test do |cmd|
        cmd.check "Prints help for declaration", %Q{
% #{cmd} -T
:...:
test_rap_uses_rap_and_tapfiles:
#{manifests.join("\n")}
:...:
}
      end
    end
  end
end