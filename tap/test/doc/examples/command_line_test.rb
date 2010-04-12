require File.expand_path('../../../tap_test_helper', __FILE__)

class CommandLineTest < Test::Unit::TestCase 
  acts_as_file_test
  acts_as_shell_test
  include TapTestMethods
  
  def test_read_data_from_stdin
    goodnight = method_root.prepare('goodnight.txt') do |io|
      io << "goodnight moon\n"
    end
    
    sh_test %Q{
      % tap load -: dump < '#{goodnight}'
      goodnight moon
    }
  end
  
  def test_pipe_data_from_stdin
    sh_test %Q{
      % echo goodnight moon | #{sh_test_options[:cmd]} load -: dump
      goodnight moon
    }, :cmd_pattern => '% ', :cmd => '2>&1 '
  end
  
  def test_manually_specify_data_with_an_argument
    sh_test %q{
      % tap load 'goodnight moon' -: dump
      goodnight moon
    }
  end
  
  def test_dump_data_to_stdout
    goodnight = method_root.prepare('goodnight.txt')
    
    cmd = "#{sh_test_options[:cmd]} load 'goodnight moon' -: dump > '#{goodnight}'"
    cmd.gsub!('2>&1 ', '')
    sh cmd, :cmd_pattern => nil, :env => default_env
    
    sh_test %Q{
      % more '#{goodnight}'
      goodnight moon
    }, :cmd_pattern => '% ', :cmd => '2>&1 '
  end
  
  def test_pipe_data_via_stdout
    sh_test %q{
      % tap load 'goodnight moon' -: dump | more
      goodnight moon
    }
  end
end