require File.join(File.dirname(__FILE__), '../doc_test_helper')
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class LoadDoc < Test::Unit::TestCase 
  include Doctest
  include MethodRoot
  
  def test_load_string
    sh_test %q{
% tap run -- load string --: dump
string
}
  end

  def test_load_pipe
    cmd = "echo goodnight moon | #{CMD} run -- load --: dump"
    assert_equal "goodnight moon", sh(cmd).strip
  end

  def test_load_redirect
    method_root.prepare(:sample, 'somefile.txt') {|io| io << "contents of somefile"}
    method_root.chdir(:sample) do
      sh_test %q{
% tap run -- load --: dump < somefile.txt
contents of somefile
}
    end
  end
end