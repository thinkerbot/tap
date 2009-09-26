require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/test'

class CmdlineDoc < Test::Unit::TestCase
  extend Tap::Test
  
  acts_as_file_test
  acts_as_shell_test :cmd_pattern => "% tap", :cmd => [
    RUBY_EXE,
    "-I'#{TAP_ROOT}/../configurable/lib'",
    "-I'#{TAP_ROOT}/../lazydoc/lib'",
    "'#{TAP_ROOT}/bin/tap'"
  ].join(" ")
  
  # === Read data from $stdin
  #   # [goodnight.txt]
  #   # goodnight moon
  # 
  #   % tap run -- load --: dump < goodnight.txt
  #   goodnight moon
  #
  def test_read_from_stdin
    path = method_root.prepare(:tmp, "goodnight.txt") {|io| io << "goodnight moon" }
    sh_test %Q{
% tap run -- load --: dump < #{path}
goodnight moon
}
  end
  
  # === Pipe data from $stdin
  #   % echo goodnight moon | tap run -- load --: dump
  #   goodnight moon
  #
  def test_pipe_from_stdin
    sh_test %Q{
echo goodnight moon | #{sh_test_options[:cmd]} run -- load --: dump
goodnight moon
}
  end
  
  # === Load data from argument
  #   % tap run -- load 'goodnight moon' --: dump
  #   goodnight moon
  #
  def test_load_data_from_argument
    sh_test %Q{
% tap run -- load 'goodnight moon' --: dump
goodnight moon
}
  end
  
  # === Dump data to $stdout
  #   % tap run -- load 'goodnight moon' --: dump > goodnight.txt
  #   % more goodnight.txt
  #   goodnight moon
  #
  def test_dump_data_to_stdout
    path = method_root.prepare(:tmp, "goodnight.txt") {}
    
    sh_test %Q{
% tap run -- load 'goodnight moon' --: dump > #{path}
}
    sh_test %Q{
more #{path}
goodnight moon
}
  end
  
  # === Pipe data via $stdout
  #   % tap run -- load 'goodnight moon' --: dump | more
  #   goodnight moon
  def test_pipe_data_via_stdout
    cmd = "% tap run -- load 'goodnight moon' --: dump | more".sub(sh_test_options[:cmd_pattern], sh_test_options[:cmd])
    assert_equal "goodnight moon", sh(cmd).strip
  end
end