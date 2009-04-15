require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'tap/task'
require 'tap/auditor'

module JoinTestMethods
  include Tap
  
  attr_accessor :app, :runlist, :results
  
  def setup
    @results = {}
    @app = App.new :debug => true do |audit|
      result = audit.trail {|a| [a.key, a.value] }
      (@results[audit.key] ||= []) << result
    end
    @app.use Tap::Auditor
    @runlist = []
  end

  def single(id)
    Task.intern({}, id, app) do |task, input| 
      @runlist << id.to_s
      "#{input} #{id}".strip
    end
  end
  
  def array(id)
    Task.intern({}, id, app) do |task, input| 
      @runlist << id.to_s
      input.collect {|str| "#{str} #{id}".strip }
    end
  end
  
  def splat(id)
    Task.intern({}, id, app) do |task, *inputs| 
      @runlist << id.to_s
      inputs.collect {|str| "#{str} #{id}".strip }
    end
  end
end unless Object.const_defined?(:JoinTestMethods)