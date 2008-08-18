require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test/script_methods'

class GeneratorTest < Test::Unit::TestCase
  acts_as_script_test
  
  TAP_EXECUTABLE_PATH = File.expand_path(File.dirname(__FILE__) + "/../../bin/tap")
  
  def default_command_path
    %Q{ruby "#{TAP_EXECUTABLE_PATH}"}
  end
  
  def test_generators
    script_test(method_dir(:output)) do |cmd|
      cmd.check "Generates a root directory", 
      "% #{cmd} generate root ." do |result|
        assert File.exists?(method_filepath(:output, 'lib'))
        assert File.exists?(method_filepath(:output, 'test'))
        assert File.exists?(method_filepath(:output, 'test/tap_test_helper.rb'))
        assert File.exists?(method_filepath(:output, 'test/tap_test_suite.rb'))
        assert File.exists?(method_filepath(:output, 'test/tapfile_test.rb'))
        assert File.exists?(method_filepath(:output, 'Rakefile'))
        assert File.exists?(method_filepath(:output, 'tapfile.rb'))
      end
      
      # cmd.check " generate task", "Prints task generator doc"
      cmd.check "Generates a sample task",
      "% #{cmd} generate task sample" do |result|
        assert File.exists?(method_filepath(:output, 'lib/sample.rb'))
        assert File.exists?(method_filepath(:output, 'test/sample_test.rb'))
      end
      
      cmd.check  "Generates a task without a test",
      "% #{cmd} generate task another --no-test" do |result|
        assert File.exists?(method_filepath(:output, 'lib/another.rb'))
        assert !File.exists?(method_filepath(:output, 'test/another_test.rb'))
      end
      
      cmd.check "Generates a nested task",
      "% #{cmd} generate task nested/sample" do |result|
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
      cmd.check "Generates the info command",
      "% #{cmd} generate command info" do |result|
        assert File.exists?(method_filepath(:output, 'cmd/info.rb'))
      end
      
      cmd.check "Destroys the info command",
      "% #{cmd} destroy command info" do |result|
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

      cmd.check "Destroys nested/sample task",
      "% #{cmd} destroy task nested/sample" do |result|
        assert !File.exists?(method_filepath(:output, 'lib/nested/sample.rb'))
        assert !File.exists?(method_filepath(:output, 'test/nested/sample_test.rb'))
      end
      
      cmd.check "Destroys another task",
      "% #{cmd} destroy task another" do |result|
        assert !File.exists?(method_filepath(:output, 'lib/another.rb'))
      end
      
      cmd.check "Destroys sample task",
      "% #{cmd} destroy task sample" do |result|
        assert !File.exists?(method_filepath(:output, 'lib/sample.rb'))
        assert !File.exists?(method_filepath(:output, 'test/sample_test.rb'))
      end
      
      cmd.check "Destroys the root directory",
      "% #{cmd} destroy root ." do |result|
        assert !File.exists?(method_dir(:output))
      end
    end
  end

end
