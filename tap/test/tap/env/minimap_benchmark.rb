require File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'tap/env/minimap'
require 'benchmark'

class MinimapBenchmark < Test::Unit::TestCase
  include Tap::Env::Minimap

  def test_minimize_speed
    puts method_name
    Benchmark.bm(30) do |x| 
      paths = (0..100).collect {|i| "path#{i}/to/file"}
      x.report("100 dir paths ") { minimize(paths) }
      
      paths = (0..1000).collect {|i| "path#{i}/to/file"}
      x.report("1k dir paths") { minimize(paths) }
      
      paths = (0..100).collect {|i| "path/to/file#{i}"}
      x.report("100 file paths ") { minimize(paths) }
      
      paths = (0..1000).collect {|i| "path/to/file#{i}"}
      x.report("1k file paths") { minimize(paths) }
    end
  end
end