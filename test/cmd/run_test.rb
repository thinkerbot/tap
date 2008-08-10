require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test/script_methods'

class RunTest < Test::Unit::TestCase
  acts_as_script_test :directories => {:output => 'output'}
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
  
  def default_command_path
    %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  end
  
  def test_run_help
    script_test do |cmd|
      cmd.check " run --help", "Prints help for run", %Q{
tap run {options} -- {task options} task INPUTS...

examples:
  tap run --help                     Prints this help
  tap run -- task --help             Prints help for task

configurations:
        --max-threads MAX_THREADS    For multithread execution
        --debug                      Flag debugging
        --force                      Force execution at checkpoints
        --quiet                      Suppress logging

options:
    -h, --help                       Show this message
    -T, --manifest                   Print a list of available tasks
}
   end
 end
 
 def test_run_manifest
   script_test do |cmd|
      cmd.check " run -T", "Prints manifest", %Q{
  dump        # the default dump task
  rake        # run rake tasks
}
    end
  end
  
 def test_run_manifest_with_tapfile_and_tasks
   script_test do |cmd|
      cmd.check " run -T", "Prints manifest", %Q{
tap:
  dump        # the default dump task
  rake        # run rake tasks
test_run_manifest_with_tapfile_and_tasks:
  sample      # sample manifest summary
  tapfile     # tapfile manifest summary
}
    end
  end
  
  def test_run_help
    script_test do |cmd|

      cmd.check " run -- sample --help", "Prints the sample task help", %Q{
Sample -- manifest summary
--------------------------------------------------------------------------------
  command line description line one
  
  line two
  
    some = code    # => line1
    some = code    # => line2
  
  a very very very long line three that requires wrapping to display properly.
  a very very very long line three that requires wrapping to display properly.
--------------------------------------------------------------------------------
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

      cmd.check " run -- tapfile/declaration --help", "Prints help for task declaration", %Q{
Tapfile::Declaration -- declaration summary
--------------------------------------------------------------------------------
  extended declaration documentation
--------------------------------------------------------------------------------
usage: tap run -- tapfile/declaration 

configurations:
        --key KEY

options:
    -h, --help                       Print this help
        --name NAME                  Specify a name
        --use FILE                   Loads inputs from file
}

      cmd.check " run -- tapfile/mixed_input --help", "Prints help for declaration with mixed inputs", %Q{
Tapfile::MixedInput -- mixed input summary
--------------------------------------------------------------------------------
  extended mixed input documentation
--------------------------------------------------------------------------------
usage: tap run -- tapfile/mixed_input INPUT INPUTS...

configurations:
        --key KEY

options:
    -h, --help                       Print this help
        --name NAME                  Specify a name
        --use FILE                   Loads inputs from file
}

      cmd.check " run -- unknown --help", "help for unknown task",  %Q{unknown task: unknown\n}
    end
  end
  
  def test_run
    script_test(method_root) do |cmd|
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
      
      cmd.check " run -- with_switch_config --help -d-", "Prints the array config help",
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
      
      # string
      cmd.check " run -- with_string_config --string \"\"", "Run with empty string syntax", 
      /with_string_config \"\"/
      
      cmd.check %Q{ run -- with_string_config --string '\\n'}, "Run with newline string syntax", 
      /with_string_config \"\\n\"/    # "\n"
      
      cmd.check %Q{ run -- with_string_config --string '\\\\n'}, "Run with newline string syntax", 
      /with_string_config \"\\\\n\"/  # "\\n"
      
      cmd.check %Q{ run -- with_string_config --string "\\n"}, "Run with newline string syntax", 
      /with_string_config \"\\n\"/    # "\n"
      
      cmd.check %Q{ run -- with_string_config --string "\\\\n"}, "Run with newline string syntax", 
      /with_string_config \"\\n\"/    # "\n"
      
      cmd.check %Q{ run -- with_string_config --string "\\\\\\n"}, "Run with newline string syntax", 
      /with_string_config \"\\\\n\"/  # "\\n"
    end
  end
end