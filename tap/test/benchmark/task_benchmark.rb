require File.expand_path('../../test_helper', __FILE__)
require 'tap/task'

class TaskBenchmark < Test::Unit::TestCase
  acts_as_subset_test
  Task = Tap::Task
  
  def test_task_init_speed
    benchmark_test(20) do |x|
      x.report("10k") { 10000.times { Task.new } }
      x.report("10k {}") { 10000.times { Task.new {} } }
      x.report("10k ({},name) {}") { 10000.times { Task.new({},'name') {} } }
    end
  end
end