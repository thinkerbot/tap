require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'
require 'stringio'

class AppTest < Test::Unit::TestCase
  
  #
  # documentation test
  #
  
  class AuditMiddleware
    attr_reader :stack, :audit

    def initialize(stack)
      @stack = stack
      @audit = []
    end

    def call(node, inputs=[])
      audit << node
      stack.call(node, inputs)
    end
  end
  
  def test_app_documentation
    app = Tap::App.new
    t = app.task {|task, *inputs| inputs }
    t.enq('a', 'b', 'c')
    t.enq(1)
    t.enq(2)
    t.enq(3)
  
    results = []
    app.on_complete {|result| results << result }
  
    app.run
    assert_equal [['a', 'b', 'c'], [1], [2], [3]], results
  
    #
    t0 = app.task {|task| "a" }
    t1 = app.task {|task, input| "#{input}.b" }
    t2 = app.task {|task, input| "#{input}.c"}
  
    t0.sequence(t1,t2)
    t0.enq
  
    results.clear
    app.run
    assert_equal ["a.b.c"], results
  
    #
    auditor = app.use AuditMiddleware
  
    t0.enq
    t2.enq("x")
    t1.enq("y")
  
    results.clear
    app.run
    assert_equal ["a.b.c", "x.c", "y.b.c"], results
                
    expected = [
    t0, t1, t2, 
    t2,
    t1, t2
    ]
    assert_equal expected, auditor.audit
  
    #
    runlist = []
    t0 = app.task {|task| runlist << task }
    t1 = app.task {|task| runlist << task }
  
    t0.depends_on(t1)
    t0.enq
  
    app.run
    assert_equal [t1, t0], runlist
  end
  
  #
  # dump test
  #
  
  class DumpExecutable < Tap::Task
    def call(input)
      input + ".#{name}"
    end
  end
  
  class Aggregator
    attr_reader :results
    def initialize
      @results = []
    end
    
    def call(result)
      results << result
    end
  end
  
  def test_apps_can_be_dumped_and_reloaded_as_yaml
    app = Tap::App.new
    t1 = DumpExecutable.new({}, 'b', app)
    t2 = DumpExecutable.new({}, 'c', app)
    t3 = DumpExecutable.new({}, 'd', app)
    
    t1.sequence(t2)
    app.enq(t1, 'a')
    app.enq(t3, 'a')
    
    app.default_join = Aggregator.new
    app.run
    assert_equal 0, app.queue.size
    
    app.enq(t1, 'A')
    dump = app.dump(StringIO.new(''))
    
    # reload
    app = YAML.load(dump.string)
    
    assert_equal Tap::App, app.class
    assert_equal 1, app.queue.size
    
    assert_equal ['a.b.c', 'a.d'], app.default_join.results
    app.run
    assert_equal ['a.b.c', 'a.d', 'A.b.c'], app.default_join.results
  end
end