require File.join(File.dirname(__FILE__), '../doc_test_helper')
require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'

class LoadDoc < Test::Unit::TestCase 
  include Doctest
  include MethodRoot
  
  def test_dump_string
    method_root.chdir(:sample, true) do
      assert_equal "", sh("#{CMD} run -- dump content --output filepath.txt")
      assert_equal "content\n", File.read("filepath.txt")
    end
  end

  def test_dump_iterate
      sh_test %q{
% tap run -- load hello -- load world -- dump --[0,1][2]i.sync
hello
world
}
  end
  
  def test_dump_pipe
      sh_test %q{
% tap run -- load hello --: dump | cat
hello
}
  end
  
  def test_dump_redirect
    method_root.chdir(:sample, true) do
      assert_equal "", sh("#{CMD} run -- load hello --: dump 1> results.txt")
      assert_equal "hello\n", sh("cat results.txt")
    end
  end
end