require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/test'

class ConsoleCmd < Test::Unit::TestCase 
  extend Tap::Test
  
  acts_as_file_test
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
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
  #   >> app.env[:dump]
  #   => Tap::Tasks::Dump
  #   >> app.info
  #   => "state: 0 (READY) queue: 0"
  #   >>
  def test_console_doc
    path = method_root.prepare(:tmp, "output.txt") {}
    cmd = "% tap console > #{path}".sub(sh_test_options[:cmd_pattern], sh_test_options[:cmd])
    IO.popen(cmd, 'w') do |io|
      io.puts "app.env[:dump]"
      io.puts "app.info"
    end
    
    assert_equal %q{
app.env[:dump]
Tap::Tasks::Dump
app.info
"state: 0 (READY) queue: 0"
}, "\n" + File.read(path)
  end
end