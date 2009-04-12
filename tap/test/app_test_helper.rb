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

  def single(id)
    lambda do |input| 
      @runlist << id.to_s
      "#{input} #{id}".strip
    end.extend Tap::App::Node
  end
  
  def array(id)
    lambda do |input| 
      @runlist << id.to_s
      input.collect {|str| "#{str} #{id}".strip }
    end.extend Tap::App::Node
  end
  
  def splat(*ids)
    lambda do |*inputs| 
      @runlist << id.to_s
      inputs.collect {|str| "#{str} #{id}".strip }
    end.extend Tap::App::Node
  end
end unless Object.const_defined?(:JoinTestMethods)