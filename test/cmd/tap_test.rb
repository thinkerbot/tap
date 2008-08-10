require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test/script_methods'

class TapTest < Test::Unit::TestCase
  acts_as_script_test 
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
  
  def default_command_path
    %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  end
  
  def test_baseline_ruby_times
    script_test do |cmd|
      cmd.command_path = nil
      
      cmd.check "", "Check time", ""
      cmd.check "ruby -e \"puts 'hello world'\"", "Prints hello world", /hello world/
      
      ['rubygems', 'yaml', 'optparse', 'fileutils', 'strscan', 'erb', 'thread'].each do |file|
        cmd.check "ruby -e \"require '#{file}'\"", "require #{file}", ""
      end
      
      cmd.check "ruby -e \"require 'rubygems';require 'rake'\"", "rake", ""
    end
  end
  
  TAP_HELP = %Q{
usage: tap <command> {options} [args]

examples:
  tap generate root .                  # generates a root dir
  tap run taskname --option input      # runs the 'taskname' task

help:
  tap help                             # prints this help
  tap command --help                   # prints help for 'command'

available commands:
  console   
  destroy   
  generate  
  manifest  
  run       
  server    

version #{Tap::VERSION} -- http://tap.rubyforge.org
}.strip
  
  def test_tap
    script_test do |cmd|
cmd.check " --help", "Prints help for the executable", %Q{
#{TAP_HELP}
}
    end
  end
  
  def test_tap_with_before_and_after_script
    script_test do |cmd|
      cmd.check " --help", "Prints help with scripts", %Q{
before line one
before line two
#{TAP_HELP}
after line one
after line two
}
    end
  end

  def test_tap_with_syntax_error_in_after
   script_test do |cmd|
     cmd.check " --help", "Syntax error in after script", %Q{
before line one
before line two
#{TAP_HELP}
Error in after script.
(eval):1: compile error
(eval):1: syntax error, unexpected tIDENTIFIER, expecting $end
puts "after line one" puts "after line two"
                          ^
}
    end
  end

  def test_tap_with_syntax_error_in_before
    script_test do |cmd|
      cmd.check " --help", "Syntax error in before script", %Q{
Error in before script.
(eval):1: compile error
(eval):1: syntax error, unexpected tIDENTIFIER, expecting $end
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
  #       assert File.exists?(method_filepath(:output, 'lib/goodnight.rb'))
  #       assert File.exists?(method_filepath(:output, 'test/goodnight_test.rb'))
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

