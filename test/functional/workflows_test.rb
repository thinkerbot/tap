require File.join(File.dirname(__FILE__), 'functional_helper')

# These tests are aimed at this basic system.
# a switches b, b.
# b forks to c and c.
# c sequences to a
# c.. merges c. and b. 
#
# C                c
# C.  B         b  c.
# C.. B. A   a  b. c..
# 
# abcab.c..
# abc.c..
# 
# [CC.BC..B.A]abcab.c..
# [CC.BC..B.A]abc.c..

class FunctionalTask < Tap::Task
  def process(input)
    log name, input
    input += (batched? ? "#{name}(#{batch_index})" : name)
  end
end

class DependencyTask < Tap::Task
  def process(runlist)
    log name, runlist.join("")
    runlist << name
  end
end

class Functional::WorkflowsTest < Test::Unit::TestCase
  
  attr_accessor :app, :a, :b, :b1, :c, :c1, :c2
  
  def setup
    @app = Tap::App.new :debug => true, :quiet => true
    
    @a  = FunctionalTask.new({}, 'a', app)
    @b  = FunctionalTask.new({}, 'b', app)
    @b1 = FunctionalTask.new({}, 'b.', app)
    @c  = FunctionalTask.new({}, 'c', app)
    @c1 = FunctionalTask.new({}, 'c.', app)
    @c2 = FunctionalTask.new({}, 'c..', app)
    
    a.switch(b, b1) do |_result|
      # sources are nil for the initial input
      # then a for the first task
      (_result._sources.length == 2 ? 0 : 1)
    end
    b.fork(c, c1)
    c.sequence(a)
    c2.merge(b1, c1)
  end

  def test_workflow
    a.enq("")
    app.run
    assert_equal ["abcab.c..", "abc.c.."], app.results(c2)
  end
  
  def test_workflow_with_batched_b
    b.initialize_batch_obj
    b.initialize_batch_obj
    
    a.enq("")
    app.run
    assert_equal [
      "ab(0)cab.c..",
      "ab(0)c.c..",
      "ab(1)cab.c..",
      "ab(1)c.c..",
      "ab(2)cab.c..",
      "ab(2)c.c.."
    ], app.results(c2)
  end
  
  def test_workflow_with_dependencies
    runlist = []
    a_  = DependencyTask.new({}, 'A', app)
    b_  = DependencyTask.new({}, 'B', app)
    b1_ = DependencyTask.new({}, 'B.', app)
    c_  = DependencyTask.new({}, 'C', app)
    c1_ = DependencyTask.new({}, 'C.', app)
    c2_ = DependencyTask.new({}, 'C..', app)
    
    a.depends_on(a_, runlist)
    a_.depends_on(b_, runlist)
    a_.depends_on(b1_, runlist)
    b_.depends_on(c_, runlist)
    b_.depends_on(c1_, runlist)
    b1_.depends_on(c2_, runlist)
    
    a.enq("1:")
    app.run
    assert_equal [
      "1:abcab.c..",
      "1:abc.c.."
    ], app.results(c2)
    assert_equal "CC.BC..B.A", runlist.join('')
    
    # implictly the dependencies are resolved twice, but
    # just to underscore the point...
    
    a.enq("2:")
    app.run
    assert_equal [
      "1:abcab.c..", 
      "1:abc.c..", 
      "2:abcab.c..",
      "2:abc.c.."
    ], app.results(c2)
    assert_equal "CC.BC..B.A", runlist.join('')
  end
end