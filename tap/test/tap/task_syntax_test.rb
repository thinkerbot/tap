require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/task'

class TaskSyntaxTest < Test::Unit::TestCase
  include Tap
  
  attr_reader :app
    
  def setup
    @app = Tap::App.new(:debug => true)
  end
  
  #
  # syntax and arity tests
  #

  class ProcessTestBase < Tap::Task
    attr_reader :runlist

    def initialize(*args)
      super
      @runlist = []
    end
  end

  ##
  class ProcessWithNoInput < Tap::Task
    attr_reader :was_in_process

    def initialize(*args)
      super
      @was_in_process = false
    end

    def process
      @was_in_process = true
    end
  end
    
  def test_process_with_no_input
    t = ProcessWithNoInput.new
    assert !t.was_in_process
    
    assert_raises(ArgumentError) do
      app.enq t, 1
      app.run
    end
    
    app.enq t
    app.run
    assert t.was_in_process
  end
  
  ##
  class ProcessWithOneInput < ProcessTestBase
    def process(input)
      runlist << input
    end
  end

  def test_process_with_one_input
    t = ProcessWithOneInput.new

    assert_raises(ArgumentError) do
      app.enq t
      app.run
    end

    app.enq t, 1
    app.run
    assert_equal [1], t.runlist
    
    assert_raises(ArgumentError) do
      app.enq t, 1, 2, 3
      app.run
    end
  end
  
  ##
  class ProcessWithMultipleInputs < ProcessTestBase
    def process(a, b)
      runlist << [a,b]
    end
  end

  def test_process_with_multiple_inputs
    t = ProcessWithMultipleInputs.new

    assert_raises(ArgumentError) do
      app.enq t
      app.run
    end
    assert_raises(ArgumentError) do 
      app.enq t, 1
      app.run
    end
    
    app.enq t, 1, 2
    app.run
    assert_equal [[1, 2]], t.runlist
  end
  
  ##
  class ProcessWithArbitraryInputs < ProcessTestBase
    def process(*args)
      runlist << args
    end
  end

  def test_process_with_arbitrary_inputs
    t = ProcessWithArbitraryInputs.new
  
    app.enq t
    app.run
    assert_equal [[]], t.runlist
  
    app.enq t, 1
    app.run
    assert_equal [[], [1]], t.runlist
  
    app.enq t, 1, 2, 3
    app.run
    assert_equal [[], [1], [1,2,3]], t.runlist
  end

  ##
  class ProcessWithMixedArbitraryInputs < ProcessTestBase
    def process(a, b, *args)
      runlist << [a, b, args]
    end
  end

  def test_process_with_mixed_arbitrary_inputs
    t = ProcessWithMixedArbitraryInputs.new
    
    assert_raises(ArgumentError) do
      app.enq t
      app.run
    end
    assert_raises(ArgumentError) do 
      app.enq t, 1
      app.run
    end
    
    app.enq t, 1, 2
    app.run
    assert_equal [[1, 2, []]], t.runlist
    
    app.enq t, 1, 2, 3
    app.run
    assert_equal [[1, 2, []], [1, 2, [3]]], t.runlist
  end

  #
  # process with default values
  #
  
  class ProcessWithDefaultValues < ProcessTestBase
    def process(input=10)
      runlist << input
    end
  end

  def test_process_with_default_values
    t = ProcessWithDefaultValues.new
    
    app.enq t
    app.run
    assert_equal [10], t.runlist
    
    app.enq t, 1
    app.run
    assert_equal [10, 1], t.runlist
    
    assert_raises(ArgumentError) do
      app.enq t, 1, 2
      app.run
    end
  end
end