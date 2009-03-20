require File.join(File.dirname(__FILE__), '../tap_test_helper')

class RunTest < Test::Unit::TestCase
  acts_as_script_test
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
  LOAD_PATHS = $:.collect {|path| "-I'#{File.expand_path(path)}'"}.uniq.join(' ')
  
  def default_command_path
    %Q{ruby #{LOAD_PATHS} "#{TAP_EXECUTABLE_PATH}"}
  end
  
  def test_run_manifest
   script_test do |cmd|
      cmd.check "Prints manifest", %Q{
% #{cmd} run -T 
  core_dump   # dumps the application
  dump        # the default dump task
  load        # the default load task
}, false
    end
  end
  
  def test_run_help
    script_test do |cmd|
      cmd.check "Prints help for run", %Q{
% #{cmd} run --help
usage: tap run FILEPATHS... [options] -- [SCHEMA]

examples:
  tap run --help                     Prints this help
  tap run -- task --help             Prints help for task

configurations:
        --[no-]audit                 Signal auditing
        --debug                      Flag debugging
        --force                      Force execution at checkpoints
        --quiet                      Suppress logging
        --verbose                    Enables extra logging (overrides quiet)

options:
    -h, --help                       Show this message
    -T, --manifest                   Print a list of available tasks
}, false
      
      cmd.check "Prints the sample task help", %Q{
% #{cmd} run -- sample --help
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
        --help                       Print this help
        --name NAME                  Specifies the task name
        --config FILE                Specifies a config file
        --use FILE                   Loads inputs to ARGV
% #{cmd} run -- sample_without_doc --help
SampleWithoutDoc

usage: tap run -- sample_without_doc INPUT

configurations:
        --key KEY

options:
        --help                       Print this help
        --name NAME                  Specifies the task name
        --config FILE                Specifies a config file
        --use FILE                   Loads inputs to ARGV
% #{cmd} run -- sample_with_splat --help
SampleWithSplat

usage: tap run -- sample_with_splat A B C...
:...:
}

      cmd.check "help for unknown task",  %Q{
% #{cmd} run -- unknown --help
unknown task: unknown
}

      cmd.check "no configurations are listed if none exist",  %Q{
% #{cmd} run -- without_configs --help
WithoutConfigs

usage: tap run -- without_configs INPUT

options:
        --help                       Print this help
        --name NAME                  Specifies the task name
        --config FILE                Specifies a config file
        --use FILE                   Loads inputs to ARGV
}
    end
  end
  
  def test_run
    script_test do |cmd|
      # variations on no task specified 
  
      cmd.check "Prints no task specified", %Q{
% #{cmd} run
no task specified
% #{cmd} run --
no task specified
% #{cmd} run -- --+ --++
no task specified
}, false

      cmd.check "Prints no such file", %Q{
% #{cmd} run unknown
No such file or directory - unknown
(did you mean 'tap run -- unknown'?)
}, false

      cmd.check "Prints unknown task", %Q{
% #{cmd} run -- --help
unknown task: --help
}, false

      # run variations
      
      path = method_root.prepare(:tmp, 'workflow.yml') do |file|
        file << "- [sample, one]"
      end
      cmd.match "Runs the workflow successfully", 
      "% #{cmd} run #{path}",
      /I\[\d\d:\d\d:\d\d\]             sample one was processed with value/
      
      cmd.match "Runs the sample task successfully", 
      "% #{cmd} run -- sample one",
      /I\[\d\d:\d\d:\d\d\]             sample one was processed with value/

      cmd.match "Runs the sample task with config", 
      "% #{cmd} run -- sample one --key alt",
      /I\[\d\d:\d\d:\d\d\]             sample one was processed with alt/

      cmd.match "Runs the sample task with alt config syntax",
      "% #{cmd} run -- sample one --key=alt",
      /I\[\d\d:\d\d:\d\d\]             sample one was processed with alt/

      cmd.match "Runs the sample task causing an argument error",
      "% #{cmd} run -- sample",
      /ArgumentError wrong number of arguments \(0 for 1\)/

      cmd.match "Runs the sample task causing an argument error",
      "% #{cmd} run -- sample one two",
      /ArgumentError wrong number of arguments \(2 for 1\)/

      # config variations

      # array
      cmd.match "Run with switch syntax", 
      "% #{cmd} run -- with_switch_config --switch", 
      /with_switch_config true/

      cmd.match  "Run with switch syntax", 
      "% #{cmd} run -- with_switch_config --no-switch",
      /with_switch_config false/

      cmd.match "Prints the array config help",
      "% #{cmd} run -- with_switch_config --help", 
      /--\[no-\]switch                a switch config/

      # list
      cmd.match "Run with list syntax", %Q{
% #{cmd} run -- with_list_config --list 1,2.2,str
% #{cmd} run -- with_list_config --list=1,2.2,str}, 
      /with_list_config \[1, 2.2, "str"\]/

      cmd.match "Prints the list config help",
      "% #{cmd} run -- with_list_config --help", 
      /--list A,B,C                 a list config/

      # array
      cmd.match "Run with array syntax",
      "% #{cmd} run -- with_array_config --array \"[1, 2.2, 'str']\"", 
      /with_array_config \[1, 2.2, "str"\]/

      cmd.match "Prints the array config help",
      "% #{cmd} run -- with_array_config --help", 
      /--array '\[a, b, c\]'          an array config/

      # hash
      cmd.match "Run with hash syntax",
      "% #{cmd} run -- with_hash_config --hc \"{one: 1, two: 2}\"", 
      /with_hash_config (\{"one"=>1, "two"=>2\}|\{"two"=>2, "one"=>1\})/

      cmd.match "Prints the hash config help",
      "% #{cmd} run -- with_hash_config --help", 
      /--hc '\{one: 1, two: 2\}'      a hash config/

      # string
      cmd.match "Run with empty string syntax",
      "% #{cmd} run -- with_string_config --string \"\"", 
      /with_string_config \"\"/

      # --string '\n'
      # --string "\n"
      backslash_n = '\n'
      cmd.match "Run with newline string syntax", %Q{
% #{cmd} run -- with_string_config --string '#{backslash_n}'
% #{cmd} run -- with_string_config --string "#{backslash_n}"},
      /with_string_config \"\\n\"/    # "\n"
      
      platform_test(:mswin, :nix) do
        # --string '\\n'
        # --string "\\n"
        escape_backslash_n = '\\' + '\n'
        cmd.match "Run with escaped newline string syntax", %Q{
% #{cmd} run -- with_string_config --string '#{escape_backslash_n}'
% #{cmd} run -- with_string_config --string "#{escape_backslash_n}"}, 
        /with_string_config \"\\\\n\"/  # '\n'
      end
      
      platform_test(:darwin) do
        # --string '\\n'
        escape_backslash_n = '\\' + '\n'
        cmd.match "Run with escaped newline string syntax", %Q{
% #{cmd} run -- with_string_config --string '#{escape_backslash_n}'}, 
        /with_string_config \"\\\\n\"/  # '\n'
        
        # --string "\\n"
        cmd.match "Run with escaped newline string syntax", %Q{
% #{cmd} run -- with_string_config --string "#{escape_backslash_n}"}, 
        /with_string_config \"\\n\"/  # "\n"
      end

    end
  end
  
  def test_run_with_dump
    script_test do |cmd|
      cmd.check "Runs and dumps workflow", %Q{
% #{cmd} run -- echo --name 1 --: echo --name 2 --: echo --name 3 --: dump --audit --yaml
["1"]
["1", "2"]
["1", "2", "3"]
# audit:
# o-[1] ["1"]
# o-[2] ["1", "2"]
# o-[3] ["1", "2", "3"]
# o-[tap/tasks/dump] [["1", "2", "3"]]
# 
--- 
- - "1"
  - "2"
  - "3"
}

      cmd.check "Workflow without auditing", %Q{
% #{cmd} run --no-audit -- echo --name 1 --: echo --name 2 --: echo --name 3 --: dump --audit --yaml
["1"]
["1", "2"]
["1", "2", "3"]
# audit:
# o-[tap/tasks/dump] [["1", "2", "3"]]
# 
--- 
- - "1"
  - "2"
  - "3"
}
    end
  end
  
  # see http://bahuvrihi.lighthouseapp.com/projects/9908-tap-task-application/tickets/148-exerun-flubs-stopterminate
  def test_run_does_not_suffer_from_stop_bug
    script_test do |cmd|
      cmd.check "Does not run after stop", %Q{
% #{cmd} run -- echo before -- stop --+ echo after
before
}, false
    end
  end
end