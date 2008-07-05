require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/test/script_methods'

class TapTest < Test::Unit::TestCase
  acts_as_script_test :directories => {:output => 'output'}
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../bin/tap")
  
  def test_baseline_ruby_times
    script_test do |cmd|
      cmd.check "ruby -e \"puts 'hello world'\"", "Prints hello world", /hello world/
      cmd.check "ruby -e \"require 'rubygems'\"", "require rubygems", ""
    end
  end
  
  def test_tap
    script_test do |cmd|
      
cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
cmd.check " --help", "Prints help for the executable", %Q{
usage: tap <command> {options} [args]

examples:
  tap generate root .                  # generates a root dir
  tap run taskname --option input      # runs the 'taskname' task

help:
  tap help                             # prints this help
  tap command --help                   # prints help for 'command'

available commands:
  cmd
  console
  destroy
  generate
  help
  run
  server

version #{Tap::VERSION} -- http://tap.rubyforge.org
}
    end
  end
  
  def test_tap_with_before_and_after_script
    script_test(method_root) do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
      cmd.check " --help", "Prints help with scripts", %Q{
before line one
before line two
usage: tap <command> {options} [args]

examples:
  tap generate root .                  # generates a root dir
  tap run taskname --option input      # runs the 'taskname' task

help:
  tap help                             # prints this help
  tap command --help                   # prints help for 'command'

available commands:
  cmd
  console
  destroy
  generate
  help
  run
  server

version #{Tap::VERSION} -- http://tap.rubyforge.org
after line one
after line two
}
    end
  end

  def test_tap_with_syntax_error_in_after
   script_test(method_root) do |cmd|
     cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
     cmd.check " --help", "Syntax error in after script", %Q{
before line one
before line two
usage: tap <command> {options} [args]

examples:
  tap generate root .                  # generates a root dir
  tap run taskname --option input      # runs the 'taskname' task

help:
  tap help                             # prints this help
  tap command --help                   # prints help for 'command'

available commands:
  cmd
  console
  destroy
  generate
  help
  run
  server

version #{Tap::VERSION} -- http://tap.rubyforge.org
Error in after script.
(eval):1: compile error
(eval):1: syntax error, unexpected tIDENTIFIER, expecting $end
puts "after line one" puts "after line two"
                          ^
}
    end
  end

  def test_tap_with_syntax_error_in_before
    script_test(method_root) do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
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
  
  def test_generators
    script_test do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
        
      cmd.check " generate root .", "Generates a root directory" do |result|
        assert File.exists?(method_filepath(:output, 'lib'))
        assert File.exists?(method_filepath(:output, 'test'))
        assert File.exists?(method_filepath(:output, 'test/tap_test_helper.rb'))
        assert File.exists?(method_filepath(:output, 'test/tap_test_suite.rb'))
        assert File.exists?(method_filepath(:output, 'tap.yml'))
        assert File.exists?(method_filepath(:output, 'Rakefile'))
        assert File.exists?(method_filepath(:output, 'ReadMe.txt'))
      end
      
      # cmd.check " generate task", "Prints task generator doc"
      cmd.check " generate task sample", "Generates a sample task" do |result|
        assert File.exists?(method_filepath(:output, 'lib/sample.rb'))
        assert File.exists?(method_filepath(:output, 'test/sample_test.rb'))
      end
      
      cmd.check " generate task another --no-test", "Generates a task without a test" do |result|
        assert File.exists?(method_filepath(:output, 'lib/another.rb'))
        assert !File.exists?(method_filepath(:output, 'test/another_test.rb'))
      end
      
      cmd.check " generate task nested/sample", "Generates a nested task" do |result|
        assert File.exists?(method_filepath(:output, 'lib/nested/sample.rb'))
        assert File.exists?(method_filepath(:output, 'test/nested/sample_test.rb'))
      end
      
      # cmd.check " generate config sample", "Generates a config for sample" do |result|
      #   assert File.exists?(method_filepath(:output, 'config/sample.yml')), result
      # end
      # 
      # cmd.check " generate config nested/sample", "Generates a config for nested/sample" do |result|
      #   assert File.exists?(method_filepath(:output, 'config/nested/sample.yml'))
      # end
      # 
      # cmd.check " generate config sample-0.1 ", "Generates a versioned config for sample" do |result|
      #   assert File.exists?(method_filepath(:output, 'config/sample-0.1.yml'))
      # end
      # 
      # cmd.check " generate config unknown", "Prints unknown task", %Q{unknown task: unknown\n}
      
      # cmd.check " generate command", "Prints command generator doc" 
      cmd.check " generate command info", "Generates the info command" do |result|
        assert File.exists?(method_filepath(:output, 'cmd/info.rb'))
      end
      
      cmd.check " destroy command info", "Destroys the info command" do |result|
        assert !File.exists?(method_filepath(:output, 'cmd/info.rb'))
      end
      
      # cmd.check " destroy config sample", "Destroys config for sample" do |result|
      #   assert !File.exists?(method_filepath(:output, 'config/sample.yml'))
      # end
      # 
      # cmd.check " destroy config nested/sample", "Destroys config for nested/sample" do |result|
      #   assert !File.exists?(method_filepath(:output, 'config/nested/sample.yml'))
      # end
      # 
      # cmd.check " destroy config sample-0.1", "Destroys versioned config for sample" do |result|
      #   assert !File.exists?(method_filepath(:output, 'config/sample-0.1.yml'))
      # end

      cmd.check " destroy task nested/sample", "Destroys nested/sample task" do |result|
        assert !File.exists?(method_filepath(:output, 'lib/nested/sample.rb'))
        assert !File.exists?(method_filepath(:output, 'test/nested/sample_test.rb'))
      end
      
      cmd.check " destroy task another", "Destroys another task" do |result|
        assert !File.exists?(method_filepath(:output, 'lib/another.rb'))
      end
      
      cmd.check " destroy task sample", "Destroys sample task" do |result|
        assert !File.exists?(method_filepath(:output, 'lib/sample.rb'))
        assert !File.exists?(method_filepath(:output, 'test/sample_test.rb'))
      end
      
      cmd.check " destroy root .", "Destroys the root directory" do |result|
        assert_equal [], method_glob(:output, "**/*")
      end
    end
  end
  
  def test_run
    script_test(method_root) do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}

      # help                      

      cmd.check " run --help", "Prints help for run", %Q{
tap run {options} -- {task options} task INPUTS...

examples:
  tap run --help                     Prints this help
  tap run -- task --help             Prints help for task

options:
    -h, --help                       Show this message
    -T, --task-manifest              Print a list of available tasks
    -d, --debug                      Trace execution and debug
        --force                      Force execution at checkpoints
        --dump                       Specifies a default dump task
        --[no-]rake                  Enables or disables rake task handling
        --quiet                      Suppress logging
}
      # manifest
      
      manifest = %Q{
===  tap tasks (#{method_filepath('lib')})
sample              # manifest summary
sample_without_doc  # 
=== rake tasks
rake clobber_package  # Remove package products
rake clobber_rdoc     # Remove rdoc products
rake default          # Default: Run tests.
rake gem              # Build the gem file .-0.0.1.gem
rake package          # Build all the packages
rake rdoc             # Build the rdoc HTML Files
rake repackage        # Force a rebuild of the package files
rake rerdoc           # Force a rebuild of the RDOC files
rake test             # Run tests
}

      cmd.check " run -T", "Prints manifest", manifest
      cmd.check " run -T -- --no-rake", "Prints manifest", manifest
      
      manifest_without_rake = %Q{
===  tap tasks (#{method_filepath('lib')})
sample              # manifest summary
sample_without_doc  # 
}

      cmd.check " run -T --no-rake", "Prints manifest wihtout rake", manifest_without_rake
      cmd.check " run -T --no-rake", "Prints manifest", manifest_without_rake
      
      # variations on no task specified 

      no_task_specified = %Q{no task specified\n}

      cmd.check " run", "Prints no task specified", no_task_specified
      cmd.check " run -- ", "Prints no task specified", no_task_specified
      cmd.check " run -- --opt", "Prints no task specified", no_task_specified
      cmd.check " run -- --help", "Prints no task specified", no_task_specified
      cmd.check " run -- --+ --++", "Prints no task specified", no_task_specified

      cmd.check " run unknown", "Prints unknown task", %Q{unknown task: unknown\n}
      
      # run variations
      
      cmd.check " run sample one", "Runs the sample task successfully", 
      /I\[\d\d:\d\d:\d\d\]             sample one was processed with value/
      
      cmd.check " run -- sample one --key alt", "Runs the sample task with config", 
      /I\[\d\d:\d\d:\d\d\]             sample one was processed with alt/
      
      cmd.check " run -- sample one --key=alt", "Runs the sample task with alt config syntax", 
      /I\[\d\d:\d\d:\d\d\]             sample one was processed with alt/
      
      # cmd.check " run sample-0.1 one", "Runs the versioned sample task"
      # /I\[\d\d:\d\d:\d\d\]             sample one was processed with sample 0.1 value/

      cmd.check " run sample", "Runs the sample task causing an argument error", 
      /ArgumentError wrong number of arguments \(0 for 1\)/

      cmd.check " run sample one two", "Runs the sample task causing an argument error" ,
      /ArgumentError wrong number of arguments \(2 for 1\)/
      
      # help variations
       
      cmd.check " run -- sample --help", "Prints the sample task help", %Q{
Sample -- manifest summary
  command line description line one
  
  line two
  
    some = code    # => line1
    some = code    # => line2
  
  a very very very long line three that requires wrapping to display properly.
  a very very very long line three that requires wrapping to display properly.

usage: tap run -- sample one

configurations:
        --key KEY                    a sample config

options:
    -h, --help                       Print this help
        --name NAME                  Specify a name
        --use FILE                   Loads inputs from file
}

      cmd.check " run -- sample_without_doc --help", "Prints the sample task help", %Q{
SampleWithoutDoc

usage: tap run -- sample_without_doc INPUT

configurations:
        --key KEY

options:
    -h, --help                       Print this help
        --name NAME                  Specify a name
        --use FILE                   Loads inputs from file
}
      cmd.check " run -- unknown --help", "help for unknown task",  %Q{unknown task: unknown\n}
      
      # cmd.check " run --debug sample", "Runs the sample task debugging"
      # cmd.check " run -- sample --debug", "Runs the sample task debugging" 
      # cmd.check " run -- sample -d-", "Runs the sample full debugging" 
      # cmd.check " -d- run -- sample --debug", "Runs the sample full debugging" 
      #
      # 
      # # should be it's own thing (test_cmd not test_run) ...
      # cmd.check " info", "Runs a command successfully"
      
      # config variations
      
      # array
      cmd.check " run -- with_switch_config --switch", "Run with switch syntax", 
      /with_switch_config true/
      
      cmd.check " run -- with_switch_config --no-switch", "Run with switch syntax", 
      /with_switch_config false/
      
      cmd.check " run -- with_switch_config --help", "Prints the array config help",
      /--\[no-\]switch                a switch config/
      
      # list
      cmd.check " run -- with_list_config --list 1,2.2,str", "Run with list syntax", 
      /with_list_config \[1, 2.2, "str"\]/
      
      cmd.check " run -- with_list_config --list=1,2.2,str", "Run with list syntax", 
      /with_list_config \[1, 2.2, "str"\]/
      
      cmd.check " run -- with_list_config --list \"[1, 2.2, 'str']\"", "Run with list syntax", 
      /with_list_config \[1, 2.2, "str"\]/
      
      cmd.check " run -- with_list_config --list \"[1, 2.2, 'str']\"", "Run with list syntax", 
      /with_list_config \[1, 2.2, "str"\]/
      
      cmd.check " run -- with_list_config --help", "Prints the list config help",
      /--list a,b,c                 a list config/
      
      # array
      cmd.check " run -- with_array_config --array \"[1, 2.2, 'str']\"", "Run with array syntax", 
      /with_array_config \[1, 2.2, "str"\]/
      
      cmd.check " run -- with_array_config --help", "Prints the array config help",
      /--array '\[a, b, c\]'          an array config/
      
      # hash
      cmd.check " run -- with_hash_config --hc \"{one: 1, two: 2}\"", "Run with hash syntax", 
      /with_hash_config (\{"one"=>1, "two"=>2\}|\{"two"=>2, "one"=>1\})/
      
      cmd.check " run -- with_hash_config --help", "Prints the hash config help",
      /--hc '\{one: 1, two: 2\}'      a hash config/
    end
  end
  
  def test_run_with_rake
    script_test(method_root) do |cmd|
      rake_test_regexp = /running default task/
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}

      # running rake tasks

      cmd.check " run rake", "Runs default rake task ('default_task')", rake_test_regexp
      cmd.check " run rake default_task", "Runs default_task", rake_test_regexp
      cmd.check " run default_task --rake", "Runs default_task", rake_test_regexp
      cmd.check " run default_task", "Runs default_task using implicit rake", rake_test_regexp
      cmd.check " run default_task --no-rake", "Treats default_task as a task name", %Q{unknown task: default_task\n}

      # rake with options

      cmd.check " run -- rake -T", "Prints rake tasks", %Q{
rake default       # Default: Run default_task.
rake default_task  # Prints 'running default task'.
}

      cmd.check " run -- rake --help", "Prints rake help", capture_sh("rake --help")
      cmd.check " run -- rake unknown_task --help", "Prints rake help", capture_sh("rake --help")
    end
  end
  
  def test_readme_doc
    script_test do |cmd|
      cmd.command_path = %Q{ruby "#{TAP_EXECUTABLE_PATH}"}

      cmd.check " generate task sample/task", "Generates a task" do |result|
        assert File.exists?(method_filepath(:output, 'lib/sample/task.rb'))
        assert File.exists?(method_filepath(:output, 'test/sample/task_test.rb'))
      end

      cmd.check " run -- sample/task --key=value input", "Run the task", /sample\/task input was processed with value/

      # cmd.check " console", "Console Interaction"
      cmd.check " destroy task sample/task", "Destroys a task" do |result|
        assert_equal [], method_glob(:output, "**/*")
      end
    end
  end
end

