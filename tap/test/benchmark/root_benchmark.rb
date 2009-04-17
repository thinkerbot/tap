require File.join(File.dirname(__FILE__), '../tap_test_helper') 
require 'tap/root'
require 'benchmark'

class RootBenchmark < Test::Unit::TestCase
  Root = Tap::Root
  
  attr_reader :r
  
  def setup
    @r = Root.new(
      :root => "./root", 
      :relative_paths => {:dir => "dir"}, 
      :absolute_paths => {:abs => '/abs/path'})
  end
  
  def path_root
    path_root = File.expand_path(".")
    while (parent_dir = File.dirname(path_root)) != path_root
      path_root = parent_dir
    end
    
    path_root
  end
  
  def test_get_speed
    puts method_name
    Benchmark.bm(20) do |x|
      n = 10000    
      x.report("10k root[] ") { n.times { r[:dir] } }
      x.report("10k root[path_root] ") { n.times { r[ path_root + "path/to/file.txt" ] } }
    end
  end
end