require 'tap/task'
require 'tap/declarations'
require 'irb'

# http://www.ruby-forum.com/topic/182335
class IRB::Irb
  alias initialize_orig initialize
  def initialize(workspace = nil, *args)
    default = IRB.conf[:DEFAULT_OBJECT]
    workspace ||= IRB::WorkSpace.new(default) if default
    initialize_orig(workspace, *args)
  end
end

module Tap
  module Tasks
    # :startdoc::task start an irb session
    #
    # Console allows interaction with tap via IRB.  Starts an IRB sssion with
    # the same context as a tapfile (a Tap::Declarations::Context).  Only one
    # console can be running at time.
    # 
    class Console < Tap::Task
      # Handles a bug in IRB that causes exit to throw :IRB_EXIT
      # and consequentially make a warning message, even on a
      # clean exit. This module resets exit to the original
      # aliased method.
      module CleanExit # :nodoc:
        def exit(ret = 0)
          __exit__(ret)
        end
      end
      
      def process
        raise "console already running" if IRB.conf[:DEFAULT_OBJECT]
        IRB.conf[:DEFAULT_OBJECT] = Declarations::Context.new(app, "console")
        IRB.start
        IRB.conf[:DEFAULT_OBJECT] = nil
        IRB.CurrentContext.extend CleanExit
      end
    end 
  end
end