require 'test/unit'

begin
  require 'lazydoc'
  require 'configurable'
rescue(LoadError)
  puts %Q{
Tests probably cannot be run because the submodules have
not been initialized. Use these commands and try again:
 
% git submodule init
% git submodule update
 
}
  raise
end

module MethodRoot
  attr_reader :method_root
  
  def setup
    super
    @method_root = Tap::Root.new("#{__FILE__.chomp(".rb")}_#{method_name}")
  end
  
  def teardown
    # clear out the output folder if it exists, unless flagged otherwise
    unless ENV["KEEP_OUTPUTS"]
      FileUtils.rm_r(method_root.root) if File.exists?(method_root.root)
    end
    super
  end
end unless Object.const_defined?(:MethodRoot)

module AppInstance
  attr_reader :app
  
  def setup
    super
    @app = Tap::App.instance = Tap::App.new(:debug => true, :quiet => true)
  end
  
  def teardown
    Tap::App.instance = nil
    super
  end
end unless Object.const_defined?(:AppInstance)

module JoinTestMethods
  attr_accessor :app, :runlist, :results
  
  def setup
    require 'tap/task'
    require 'tap/auditor'
    
    @results = {}
    @app = Tap::App.new :debug => true do |audit|
      result = audit.trail {|a| [a.key, a.value] }
      (@results[audit.key] ||= []) << result
    end
    @app.use Tap::Auditor
    @runlist = []
  end

  def single(id)
    Tap::Task.intern({}, id, app) do |task, input| 
      @runlist << id.to_s
      "#{input} #{id}".strip
    end
  end
  
  def array(id)
    Tap::Task.intern({}, id, app) do |task, input| 
      @runlist << id.to_s
      input.collect {|str| "#{str} #{id}".strip }
    end
  end
  
  def splat(id)
    Tap::Task.intern({}, id, app) do |task, *inputs| 
      @runlist << id.to_s
      inputs.collect {|str| "#{str} #{id}".strip }
    end
  end
end unless Object.const_defined?(:JoinTestMethods)

module TestUtils
  module_function
  
  def match_platform?(*platforms)
    platforms.each do |platform|
      platform.to_s =~ /^(non_)?(.*)/

      non = true if $1
      match_platform = !RUBY_PLATFORM.index($2).nil?
      return false unless (non && !match_platform) || (!non && match_platform)
    end

    true
  end
end unless Object.const_defined?(:TestUtils)
