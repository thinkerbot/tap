require File.join(File.dirname(__FILE__), '../doc_test_helper')
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class ConsoleDoc < Test::Unit::TestCase 
  include Doctest
  
  #
  # help
  #
  
  def test_run_prints_help
    sh_match "% tap console --help", 
    /usage: tap console/
  end
  
  #
  # interaction
  #
  
  #   % tap console
  #   >> env.tasks['tap/dump']
  #   => Tap::Dump
  #   >> app.info
  #   => "state: 0 (READY) queue: 0"
  #   >>
  def test_console_doc
    tempfile do |output, path|
      output.close
      
      cmd = "% tap console > #{path}".sub(CMD_PATTERN, CMD)
      IO.popen(cmd, 'w') do |io|
        io.puts "env.tasks['tap/dump']"
        io.puts "app.info"
      end
      
      assert_equal %q{
env.tasks['tap/dump']
Tap::Dump
app.info
"state: 0 (READY) queue: 0"
}, "\n" + File.read(output.path)
    end
  end
end