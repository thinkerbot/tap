require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/task'


class TaskSyntaxTest < Test::Unit::TestCase
  include Tap
  include TapTestMethods
  
  acts_as_tap_test
  
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
    
    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq 1
        app.run
      end
      
      t.enq
      app.run
      assert t.was_in_process
    end
  end

  def test_block_with_no_input
    was_in_block = false
    t = Tap::Task.new do |task|
      was_in_block = true
    end

    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq 1
        app.run
      end
      
      t.enq
      app.run
      assert was_in_block
    end
  end
  
  ##
  class ProcessWithOneInput < ProcessTestBase
    def process(input)
      runlist << input
    end
  end

  def test_process_with_one_input
    t = ProcessWithOneInput.new

    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq
        app.run
      end

      t.enq 1
      app.run
      assert_equal [1], t.runlist
      
      assert_raise(ArgumentError) do
        t.enq 1, 2, 3
        app.run
      end
    end
  end

  def test_block_with_one_input
    runlist = []
    t = Tap::Task.new do |task, input|
      runlist << input
    end

    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq
        app.run
      end
      assert_raise(ArgumentError) do 
        t.enq 1, 2
        app.run
      end
      
      t.enq 1
      app.run
      assert_equal [1], runlist
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

    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq
        app.run
      end
      assert_raise(ArgumentError) do 
        t.enq 1
        app.run
      end
      
      t.enq 1, 2
      app.run
      assert_equal [[1, 2]], t.runlist
    end
  end
  
  def test_block_with_multiple_inputs
    runlist = []
    t = Tap::Task.new do |task, a, b|
      runlist << [a,b]
    end
  
    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq
        app.run
      end
      assert_raise(ArgumentError) do 
        t.enq 1
        app.run
      end
      
      t.enq 1, 2
      app.run
      assert_equal [[1, 2]], runlist
    end
  end
  
  ##
  class ProcessWithArbitraryInputs < ProcessTestBase
    def process(*args)
      runlist << args
    end
  end

  def test_process_with_arbitrary_inputs
    t = ProcessWithArbitraryInputs.new
  
    with_config :debug => true do
      t.enq
      app.run
      assert_equal [[]], t.runlist
    
      t.enq 1
      app.run
      assert_equal [[], [1]], t.runlist
    
      t.enq 1, 2, 3
      app.run
      assert_equal [[], [1], [1,2,3]], t.runlist
    end
  end

  def test_block_with_arbitrary_inputs
    runlist = []
    t = Tap::Task.new do |task, *args|
      runlist << args
    end

    with_config :debug => true do
      t.enq
      app.run
      assert_equal [[]], runlist
    
      t.enq 1
      app.run
      assert_equal [[], [1]], runlist
    
      t.enq 1, 2, 3
      app.run
      assert_equal [[], [1], [1,2,3]], runlist
    end
  end

  ##
  class ProcessWithMixedArbitraryInputs < ProcessTestBase
    def process(a, b, *args)
      runlist << [a, b, args]
    end
  end

  def test_process_with_mixed_arbitrary_inputs
    t = ProcessWithMixedArbitraryInputs.new
    
    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq
        app.run
      end
      assert_raise(ArgumentError) do 
        t.enq 1
        app.run
      end
      
      t.enq 1, 2
      app.run
      assert_equal [[1, 2, []]], t.runlist
      
      t.enq 1, 2, 3
      app.run
      assert_equal [[1, 2, []], [1, 2, [3]]], t.runlist
    end
  end
  
  def test_block_with_mixed_arbitrary_inputs
    runlist = []
    t = Tap::Task.new do |task, a, b, *args|
      runlist << [a, b, args]
    end

    with_config :debug => true do
      assert_raise(ArgumentError) do
        t.enq
        app.run
      end
      assert_raise(ArgumentError) do 
        t.enq 1
        app.run
      end
      
      t.enq 1, 2
      app.run
      assert_equal [[1, 2, []]], runlist
      
      t.enq 1, 2, 3
      app.run
      assert_equal [[1, 2, []], [1, 2, [3]]], runlist
    end
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
    
    with_config :debug => true do
      t.enq
      app.run
      assert_equal [10], t.runlist
      
      t.enq 1
      app.run
      assert_equal [10, 1], t.runlist
      
      assert_raise(ArgumentError) do
        t.enq 1, 2
        app.run
      end
    end
  end
  
end