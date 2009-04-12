require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'benchmark'

class AppBenchmark < Test::Unit::TestCase
  
  def intern(app, &block)
    Tap::App::Executable.initialize(block, :call, app)
  end
  
  #
  # benchmarks
  #
  
  def test_run_speed
    app = Tap::App.new(:quiet => true) {|audit| }
    t = intern(app) {}
    
    puts method_name
    Benchmark.bm(20) do |x|
      n = 10000
          
      x.report("10k enq ") { n.times { t.enq } }
      x.report("10k run ") { n.times {}; app.run }
      x.report("10k _execute ") { n.times { t._execute } }
    end
  end
end