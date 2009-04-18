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
