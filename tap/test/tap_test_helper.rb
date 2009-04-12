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

module HelperMethods
  def match_platform?(*platforms)
    platforms.each do |platform|
      platform.to_s =~ /^(non_)?(.*)/

      non = true if $1
      match_platform = !RUBY_PLATFORM.index($2).nil?
      return false unless (non && !match_platform) || (!non && match_platform)
    end

    true
  end
end unless Object.const_defined?(:HelperMethods)

Test::Unit::TestCase.extend HelperMethods

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

# require 'tap/test'
# 
# unless defined?(ObjectWithExecute)
#   class ObjectWithExecute
#     def execute(input)
#       input
#     end
#   end
# 

#   
#   # Some convenience methods used in testing tasks, workflows, app, etc.
#   module TapTestMethods # :nodoc:
#     attr_accessor  :runlist
#     
#     # Setup clears the test using clear_tasks and assures that Tap::App.instance 
#     # is the test-specific application.
#     def setup
#       super
#       clear_runlist
#     end
# 
#     # Clears the runlist.
#     def clear_runlist
#       # clear the attributes
#       @runlist = []
#     end
# 
#     # A tracing procedure.  echo adds input to runlist then returns input.
#     def echo
#       lambda do |task, *inputs| 
#         @runlist << inputs
#         inputs
#       end
#     end
#     
#     # A tracing procedure for numeric inputs.  add_one adds the input to 
#     # runlist then returns input + 1.
#     def add_one
#       lambda do |task, input| 
#         @runlist << input
#         input += 1
#       end
#     end
#   end
# end