require File.expand_path('../../tap_test_helper', __FILE__)
require 'tap/app'

class AppBenchmark < Test::Unit::TestCase
  acts_as_subset_test
  
  attr_reader :app
  
  def setup
    super
    @app = Tap::App.new(:quiet => true)
  end
  
  #
  # benchmarks
  #
  
  def test_call_speed
    benchmark_test(20) do |x|
      n = 10000
      
      app.set('app', app)
      x.report("10k stop") { n.times { app.stop } }
      x.report("10k call stop") { n.times { app.call('sig' => 'stop')} }
      x.report("10k call app/stop") { n.times { app.call('sig' => 'app/stop')} }
    end
  end
  
  def test_run_speed
    benchmark_test(20) do |x|
      n = 10000
      
      node = lambda {|input| }
      x.report("10k enq ")  { n.times { app.enq(node, nil) } }
      x.report("10k run ")  { n.times {}; app.run }
      x.report("10k call ") { n.times { node.call(nil) } }
    end
  end
  
  module Unsynchronize
    def synchronize
      yield
    end
  end
  
  def test_unsynchronized_run_speed
    benchmark_test(20) do |x|
      app.queue.extend(Unsynchronize)
      n = 10000
      
      node = lambda {|input| }
      x.report("10k enq ")  { n.times { app.enq(node, nil) } }
      x.report("10k run ")  { n.times {}; app.run }
      x.report("10k call ") { n.times { node.call(nil) } }
    end
  end
end