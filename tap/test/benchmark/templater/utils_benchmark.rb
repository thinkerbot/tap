require File.expand_path('../../../tap_test_helper', __FILE__)
require 'tap/test/unit'
require 'tap/templater'

class TemplaterUtilsBenchmark < Test::Unit::TestCase
  include Tap::Templater::Utils
  
  acts_as_subset_test
  
  def test_nest_speed
    benchmark_test(20) do |x|
      content = "some content\n" * 100
      nesting = [['module Sample', 'end'], ['module Nest', 'end']]
      
      n = 1000
      x.report("#{n}x nest") { n.times { nest(nesting) {content} } }
    end
  end
end