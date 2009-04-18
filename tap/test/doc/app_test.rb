require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/app'
require 'stringio'

class AppTest < Test::Unit::TestCase
  include Tap
  
  attr_reader :app, :runlist, :results
    
  def setup
    @results = []
    @app = Tap::App.new(:debug => true) do |result|
      @results << result
      result
    end
    @runlist = []
  end
  
  def intern(&block)
    App::Node.intern(&block)
  end
  
  # returns a tracing executable. node adds the key to 
  # runlist then returns input + key
  def node(key)
    intern do |input| 
      @runlist << key
      input += key
    end
  end
  
  #
  # documentation test
  #
  
  def test_app_documentation
    app = App.instance
  
    t = Task.intern {|task, *inputs| inputs }
    t.enq('a', 'b', 'c')
    t.enq(1)
    t.enq(2)
    t.enq(3)
  
    app.run
    assert_equal [['a', 'b', 'c'], [1], [2], [3]], app.results(t)
  
    ###
  
    t0 = Task.intern {|task| "0" }
    t1 = Task.intern {|task, input| "#{input}:1" }
    t2 = Task.intern {|task, input| "#{input}:2"}
  
    t0.on_complete {|_result| t1.enq(_result) }
    t1.on_complete {|_result| t2.enq(_result) }
    
    t0.enq
    app.run
    assert_equal [], app.results(t0, t1)
    assert_equal ["0:1:2"], app.results(t2)
  
    ###
  
    t2.enq("a")
    t1.enq("b")
    app.run
    assert_equal ["0:1:2", "a:2", "b:1:2"], app.results(t2)
  
    t0.name = "zero"
    t1.name = "one"
    t2.name = "two"
  
    trails = app._results(t2).collect do |_result|
      _result.dump
    end
  
    expected = %q{
o-[zero] "0"
o-[one] "0:1"
o-[two] "0:1:2"

o-[] "a"
o-[two] "a:2"

o-[] "b"
o-[one] "b:1"
o-[two] "b:1:2"
}
    assert_equal expected, "\n" + trails.join("\n")
  
    ###
    
    runlist = []
    t0 = Task.intern {|task| runlist << task }
    t1 = Task.intern {|task| runlist << task }
  
    t0.depends_on(t1)
    t0.enq
  
    app.run
    assert_equal [t1, t0], runlist
  
    ###
  
    t0.enq
    app.run
    assert_equal [t1, t0, t0], runlist
  
    ###
  
    array = []
  
    m = array._method(:push)
    m.enq(1)
    m.enq(2)
    m.enq(3)
  
    assert_equal true, array.empty?
    app.run
    assert_equal [1, 2, 3], array
  end
  
  def test_old_app_documentation
    t0 = Task.intern {|task, input| "#{input}.0" }
    t0.enq('a')
    app.enq(t0, 'b')
  
    app.run
    assert_equal ['a.0', 'b.0'], app.results(t0)
    
    ####
    app.aggregator.clear
  
    t1 = Task.intern {|task, input| "#{input}.1" }
    t0.on_complete {|_result| t1.enq(_result) }
    t0.enq 'c'
  
    app.run
    assert_equal [], app.results(t0)
    assert_equal ['c.0.1'], app.results(t1)
    
    ####
    runlist = []
    t0 = Task.intern {|task| runlist << task }
    t1 = Task.intern {|task| runlist << task }
  
    t0.depends_on(t1)
    t0.enq
  
    app.run
    assert_equal [t1, t0], runlist
  
    t0.enq
    app.run
    assert_equal [t1, t0, t0], runlist
    
    ####
    array = []
  
    # longhand
    m = array._method(:push)
    m.enq(1)
  
    # shorthand
    app.mq(array, :push, 2)
  
    assert array.empty?
    app.run
    assert_equal [1, 2], array
    
    ####
    add_one  = Tap::Task.intern({}, 'add_one')  {|task, input| input += 1 }
    add_five = Tap::Task.intern({}, 'add_five') {|task, input| input += 5 }
  
    add_one.on_complete do |_result|
      # _result is the audit
      current_value = _result.value
  
      if current_value < 3 
        add_one.enq(_result)
      else
        add_five.enq(_result)
      end
    end
    
    add_one.enq(0)
    add_one.enq(1)
    add_one.enq(2)
  
    app.run
    assert_equal [8,8,8], app.results(add_five)

    expected = %Q{
o-[] 2
o-[add_one] 3
o-[add_five] 8
 
o-[] 1
o-[add_one] 2
o-[add_one] 3
o-[add_five] 8
 
o-[] 0
o-[add_one] 1
o-[add_one] 2
o-[add_one] 3
o-[add_five] 8
}

    assert_equal expected, "\n" + Tap::Support::Audit.dump(app._results(add_five), "")
  end
  
  #
  # dump test
  #
  
  class DumpExecutable
    include Tap::App::Node
    
    def initialize(name)
      @name = name
      @app = nil
      @join = nil
      @dependencies = []
    end
    
    def call(input)
      input + ".#{@name}"
    end
  end
  
  def test_apps_can_be_dumped_and_reloaded_as_yaml
    app = Tap::App.new
    t1 = DumpExecutable.new('b')
    t2 = DumpExecutable.new('c')
    t3 = DumpExecutable.new('d')
    
    t1.sequence(t2)
    app.enq(t1, 'a')
    app.enq(t3, 'a')
    
    app.run
    assert_equal 0, app.queue.size
    
    app.enq(t1, 'A')
    dump = app.dump(StringIO.new(''))
    d = YAML.load(dump.string)
    
    assert_equal Tap::App, d.class
    assert_equal 1, d.queue.size
    assert_equal 2, d.aggregator.size
  
    keys = d.aggregator.to_hash.keys
    assert_equal ['a.b.c', 'a.d'], d.aggregator.results(*keys).sort
    
    d.run
    keys = d.aggregator.to_hash.keys
    assert_equal ['A.b.c', 'a.b.c', 'a.d'], d.aggregator.results(*keys).sort
  end
end