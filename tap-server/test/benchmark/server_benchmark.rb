class ServerBenchmark
  #
  # benchmark test
  #
  
  class BenchmarkController
    def self.call(env)
      [200, {}, env['PATH_INFO']]
    end
  end

  def test_call_speed
    benchmark_test(20) do |x|
      server.controllers['route'] = BenchmarkController
      n = 10*1000
      
      env = Rack::MockRequest.env_for("/route")
      x.report("10k call") { n.times { BenchmarkController.call(env.dup) } }
      assert_equal [200, {}, ["/"]], server.call(env)
      
      env = Rack::MockRequest.env_for("/route")
      x.report("10k route") { n.times { server.call(env.dup) } }
      assert_equal [200, {}, ["/"]], server.call(env)
      
      env = Rack::MockRequest.env_for("/route/to/resource")
      x.report("10k route/path") { n.times { server.call(env.dup) } }
      assert_equal [200, {}, ["/to/resource"]], server.call(env)
      
      method_root.prepare(:lib, 'bench.rb') do |file| 
        file << %Q{# ::controller\nclass Bench < ServerTest::BenchmarkController; end}
      end
      
      env = Rack::MockRequest.env_for("/bench")
      x.report("1k dev env") { 1000.times { server.call(env.dup) } }
      assert_equal [200, {}, ["/"]], server.call(env)
      
      server.environment = :production
      env = Rack::MockRequest.env_for("/bench")
      x.report("10k pro env") { n.times { server.call(env.dup) } }
      assert_equal [200, {}, ["/"]], server.call(env)
    end
  end
end