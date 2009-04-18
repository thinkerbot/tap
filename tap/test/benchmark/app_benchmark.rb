require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'benchmark'

class AppBenchmark < Test::Unit::TestCase
  
  #
  # benchmarks
  #
  
  def test_run_speed
    app = Tap::App.new(:quiet => true) {|audit| }
    t = Tap::App::Node.intern {}
    
    puts method_name
    Benchmark.bm(20) do |x|
      n = 10000
          
      x.report("10k enq ") { n.times { app.enq(t) } }
      x.report("10k run ") { n.times {}; app.run }
      x.report("10k call ") { n.times { t.call } }
    end
  end
end