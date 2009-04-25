require File.join(File.dirname(__FILE__), '../rap_test_helper')

class ReadmeTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  
  RAP_ROOT = File.expand_path(File.dirname(__FILE__) + "/../..")
  LOAD_PATHS = [
    "-I'#{RAP_ROOT}/../configurable/lib'",
    "-I'#{RAP_ROOT}/../lazydoc/lib'",
    "-I'#{RAP_ROOT}/../tap/lib'"
  ]
  
  CMD_PATTERN = "% rap"
  CMD = (["TAP_GEMS= ruby"] + LOAD_PATHS + ["'#{RAP_ROOT}/bin/rap'"]).join(" ")
  
  def test_readme
    method_root.prepare(:tmp, 'Rapfile') do |file|
      file << %q{
require 'rap/declarations'
include Rap::Declarations

desc "your basic goodnight moon task"

# Says goodnight with a configurable message.
task(:goodnight, :obj, :message => 'goodnight') do |task, args|
  puts "#{task.message} #{args.obj}\n"
end}
    end
    
    method_root.chdir(:tmp) do
      sh_test %Q{
% rap goodnight moon
goodnight moon
}
      sh_test %Q{
% rap goodnight world --message hello
hello world
}

      sh_test %Q{
% rap goodnight moon
goodnight moon
}

      sh_test "% rap goodnight --help" do |output|
        assert output =~ /Goodnight -- your basic goodnight moon task/
        assert output =~ /Says goodnight with a configurable message/
        assert output =~ /rap goodnight OBJ/
        assert output =~ /--message MESSAGE/
      end
    end
    
    test = method_root.prepare(:tmp, 'test.rb') do |file|
        file << %q{
load 'Rapfile'
require 'test/unit'
require 'stringio'

class RapfileTest < Test::Unit::TestCase
  def test_the_goodnight_task
    $stdout = StringIO.new

    task = Goodnight.new
    assert_equal 'goodnight', task.message

    task.process('moon')
    assert_equal "goodnight moon\n", $stdout.string
  end
end}
    end
    
    method_root.chdir(:tmp) do
      result = sh("ruby #{LOAD_PATHS.join(" ")} -I#{RAP_ROOT}/lib #{test}")
      assert_match(/1 tests, 2 assertions, 0 failures, 0 errors/, result)
    end
  end
end