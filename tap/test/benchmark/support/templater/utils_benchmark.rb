require File.join(File.dirname(__FILE__), '../../../tap_test_helper')
require 'tap/support/templater'
require 'benchmark'

class TemplaterUtilsBenchmark < Test::Unit::TestCase
  include Benchmark
  include Tap::Support::Templater::Utils
  
  def test_nest_speed
    puts method_name
    bm(20) do |x|
      content = "some content\n" * 100
      nesting = [['module Sample', 'end'], ['module Nest', 'end']]
      
      n = 1000
      x.report("#{n}x nest") { n.times { nest(nesting) {content} } }
    end
  end
end