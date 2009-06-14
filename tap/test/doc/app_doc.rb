require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap'
require 'stringio'

class AppDoc < Test::Unit::TestCase
  
  #
  # dump test
  #
  
  class DumpExecutable < Tap::Task
    config :name, ""
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
    t1 = DumpExecutable.new({:name => 'b'}, app)
    t2 = DumpExecutable.new({:name => 'c'}, app)
    t3 = DumpExecutable.new({:name => 'd'}, app)
    
    t1.sequence(t2)
    app.enq(t1, 'a')
    app.enq(t3, 'a')
    
    app.default_joins << Aggregator.new
    app.run
    assert_equal 0, app.queue.size
    
    app.enq(t1, 'A')
    dump = app.dump(StringIO.new(''))
    
    # reload
    app = YAML.load(dump.string)
    
    assert_equal Tap::App, app.class
    assert_equal 1, app.queue.size
    
    assert_equal ['a.b.c', 'a.d'], app.default_joins[0].results
    app.run
    assert_equal ['a.b.c', 'a.d', 'A.b.c'], app.default_joins[0].results
  end
end