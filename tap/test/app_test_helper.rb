require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/app'

module JoinTestMethods
  attr_accessor :app, :runlist, :results
    
  def setup
    @results = {}
    @app = Tap::App.new :debug => true do |audit|
      result = audit.trail {|a| [a.key, a.value] }
      (@results[audit.key] ||= []) << result
    end
    @runlist = []
  end
  
  def intern(&block)
    Tap::App::Executable.initialize(block, :call, app)
  end
  
  def single_tracers(*ids)
    ids.collect do |id|
      intern do |input| 
        @runlist << id.to_s
        "#{input} #{id}".strip
      end
    end
  end
  
  def multi_tracers(*ids)
    ids.collect do |id|
      intern do |input| 
        @runlist << id.to_s
        input.collect {|str| "#{str} #{id}".strip }
      end
    end
  end
  
  def splat_tracers(*ids)
    ids.collect do |id|
      intern do |*inputs| 
        @runlist << id.to_s
        inputs.collect {|str| "#{str} #{id}".strip }
      end
    end
  end
end unless Object.const_defined?(:JoinTestMethods)