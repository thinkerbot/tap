require 'test/unit'
# setup testing with submodules
# begin
#   require File.join(File.dirname(__FILE__), '../lib/tap')
# rescue(LoadError)
#   puts %Q{
# Tests probably cannot be run because the submodules have
# not been initialized.  Use these commands and try again:
# 
#   % git submodule init
#   % git submodule update
# 
# }
#   raise
# end

# require 'tap/test'
# 
# unless defined?(ObjectWithExecute)
#   class ObjectWithExecute
#     def execute(input)
#       input
#     end
#   end
# 
#   class Tracer
#     include Tap::Support::Executable
# 
#     class << self
#       def intern(n, runlist, &block)
#         Array.new(n) { |index| new(index, runlist, &block) }
#       end
#     end
# 
#     def initialize(index, runlist, &block)
#       @index = index
#       @runlist = runlist
# 
#       @app = Tap::App.instance
#       @method_name = :trace
#       @on_complete_block =nil
#       @dependencies = []
#       @block = block || lambda {|task, str| task.mark(str) }
#     end
# 
#     def id
#       @index.to_s
#     end
#     
#     def mark(input)
#       "#{input} #{id}".strip
#     end
#     
#     def inspect
#       "Tracer(#{@index})"
#     end
# 
#     def trace(*inputs)
#       @runlist << id
#       @block.call(self, *inputs)
#     end
#   end
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