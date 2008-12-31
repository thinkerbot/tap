require File.join(File.dirname(__FILE__), '../tap_test_helper')

class TapTest < Test::Unit::TestCase
  acts_as_script_test 
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
  LOAD_PATHS = $:.collect {|path| "-I'#{File.expand_path(path)}'"}.uniq.join(' ')
  
  def default_command_path
    %Q{ruby #{LOAD_PATHS} "#{TAP_EXECUTABLE_PATH}"}
  end
  
  def test_baseline_ruby_times
    script_test do |cmd|
      cmd.command_path = nil

      cmd.time "hello world", "ruby -e \"puts 'hello world'\""
      ['rubygems', 'yaml', 'optparse', 'fileutils', 'strscan', 'erb', 'thread'].each do |file|
        cmd.time file, "ruby -e \"require '#{file}'\""
      end
      cmd.time "rake", "ruby -rubygems -e \"require 'rubygems';require 'rake'\""
    end
  end
  
  TAP_HELP = %Q{
usage: tap <command> {options} [args]

examples:
  tap generate root .                  # generates a root dir
  tap run taskname --option input      # runs the 'taskname' task

help:
  tap --help                           # prints this help
  tap command --help                   # prints help for 'command'

available commands:
  console   
  manifest  
  run       

version #{Tap::VERSION} -- http://tap.rubyforge.org
}.strip
  
  def test_tap
    script_test do |cmd|
      cmd.check "Prints help for the executable", %Q{
% #{cmd} --help
#{TAP_HELP}
}, false
    end
  end
  
  def test_tap_with_unknown_command
    script_test do |cmd|
      cmd.check "Prints help for the executable", %Q{
% #{cmd} unknown
Unknown command: 'unknown'
Type 'tap --help' for usage information.
}, false
    end
  end
  
  def test_tap_with_before_and_after_script
    script_test do |cmd|
      cmd.check "Prints help with scripts", %Q{
% #{cmd} --help
before line one
before line two
#{TAP_HELP}
after line one
after line two
}, false
    end
  end

  def test_tap_with_syntax_error_in_after
   script_test do |cmd|
     cmd.check "Syntax error in after script", %Q{
% #{cmd} --help
before line one
before line two
#{TAP_HELP}
Error in after script.
(eval):1: compile error
(eval):1: syntax error:...:
puts "after line one" puts "after line two"
                          ^
}
    end
  end

  def test_tap_with_syntax_error_in_before
    script_test do |cmd|
      cmd.check "Syntax error in before script", %Q{
% #{cmd} --help
Error in before script.
(eval):1: compile error
(eval):1: syntax error:...:
puts "before line one" puts "before line two"
                           ^
after line one
after line two
}
    end
  end

  # def test_readme_doc
  #   script_test do |cmd|
  #     cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  # 
  #     cmd.check " generate task goodnight", "Generates a task" do |result|
  #       assert File.exists?(method_root.filepath(:output, 'lib/goodnight.rb'))
  #       assert File.exists?(method_root.filepath(:output, 'test/goodnight_test.rb'))
  #     end
  # 
  #     cmd.check " run -- goodnight moon --message hello", "Run the task", /hello moon/
  # 
  #     # cmd.check " console", "Console Interaction"
  #     cmd.check " destroy task goodnight", "Destroys a task" do |result|
  #       assert_equal [], method_glob(:output, "**/*.rb")
  #     end
  #   end
  # end
end

