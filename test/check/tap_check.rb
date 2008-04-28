require 'rubygems'

require  File.join(File.dirname(__FILE__), '/../tap_test_helper')
require 'tap/test/script_methods'

class TapExecutableTest < Test::Unit::TestCase
  acts_as_script_test :directories => {:output => 'output'}
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
  
  def test_help_and_documentation
    script_test do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
      cmd.check " --help", "Prints help for the executable" 
      cmd.check " run --help", "Prints help for run" 
      cmd.check " run", "Prints no task specified" 
      cmd.check " run unknown", "Prints unknown task" 
      cmd.check " generate root", "Prints root generator documentation" 
    end
  end
  
  def test_generators
    script_test do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
        
      cmd.check " generate root .", "Generates a root directory" 
      cmd.check " generate task", "Prints task generator doc"
      cmd.check " generate task sample", "Generates a sample task" 
      cmd.check " generate task another --no-test", "Generates a task without a test" 
      cmd.check " generate task nested/sample", "Generates a nested task" 
      cmd.check " generate file_task", "Prints file_task generator doc"
      cmd.check " generate file_task sample_file", "Generates a sample file task" 
      cmd.check " generate file_task another_file --no-test", "Generates a file task without a test" 
      cmd.check " generate config sample", "Generates a config for sample" 
      cmd.check " generate config sample-0.1 ", "Generates a versioned config for sample" 
      cmd.check " generate config nested/sample", "Generates a config for nested/sample" 
      cmd.check " generate config unknown", "Prints unknown task" 
      cmd.check " generate command", "Prints command generator doc" 
      cmd.check " generate command info", "Generates the info command" 
      
      cmd.check " destroy command info", "Destroys the info command" 
      cmd.check " destroy config sample", "Destroys config for sample" 
      cmd.check " destroy config sample-0.1", "Destroys versioned config for sample" 
      cmd.check " destroy config nested/sample", "Destroys config for nested/sample" 
      cmd.check " destroy task sample", "Destroys sample task" 
      cmd.check " destroy task nested/sample", "Destroys nested/sample task" 
      cmd.check " destroy task another", "Destroys another task" 
      cmd.check " destroy file_task sample_file", "Destroys sample file task" 
      cmd.check " destroy file_task another_file", "Destroys another file task" 
      cmd.check " destroy root .", "Destroys the root directory" do
        assert_equal [], method_glob(:output, "**/*")
      end
    end
  end
  
  def test_run
    script_test(method_root) do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
        
      cmd.check " run -- rake -T", "Prints rake tasks"
      cmd.check " run rake", "Runs default rake task ('test')"
      cmd.check " run test", "Runs test"

      cmd.check " run -- sample --help", "Prints the sample task help" 
      cmd.check " run sample", "Runs the sample task causing an error" 
      cmd.check " run sample one two", "Runs the sample task causing an error" 
      cmd.check " run --debug sample", "Runs the sample task debugging"
      cmd.check " run -- sample --debug", "Runs the sample task debugging" 
      cmd.check " run -- sample -d-", "Runs the sample full debugging" 
      cmd.check " -d- run -- sample --debug", "Runs the sample full debugging" 
      cmd.check " run sample one", "Runs the sample task successfully" 
      cmd.check " run sample-0.1 one", "Runs the versioned sample task" 
      
      # should be it's own thing (test_cmd not test_run) ...
      cmd.check " info", "Runs a command successfully" 
    end
  end
  
  def test_readme_doc
    script_test do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
      
      cmd.check " generate task sample/task", "Generates a task"
      cmd.check " run -- sample/task --key=value input", "Run the task"
      cmd.check " console", "Console Interaction"
      cmd.check " destroy task sample/task", "Destroys a task" do
        assert_equal [], method_glob(:output, "**/*")
      end
    end
  end
end

