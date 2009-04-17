require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'tap/task'
require 'benchmark'

class TaskBenchmark < Test::Unit::TestCase
  Task = Tap::Task
  
  def test_task_init_speed
    puts method_name
    Benchmark.bm(20) do |x|
      x.report("10k") { 10000.times { Task.new } }
      x.report("10k {}") { 10000.times { Task.new {} } }
      x.report("10k ({},name) {}") { 10000.times { Task.new({},'name') {} } }
    end
  end
end