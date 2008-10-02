require 'rubygems'

require File.dirname(__FILE__) + '/../lib/tap'
require 'tap/test'

unless defined?(ObjectWithExecute)
  class ObjectWithExecute
    def execute(input)
      input
    end
  end
end

unless defined?(TapTestMethods)
  
  # Some convenience methods used in testing tasks, workflows, app, etc.
  module TapTestMethods # :nodoc:
    attr_accessor  :runlist
    
    # Setup clears the test using clear_tasks and assures that Tap::App.instance 
    # is the test-specific application.
    def setup
      super
      clear_runlist
    end

    # Clears all declared tasks, sets the application trace option to false, makes directories (if flagged
    # and as needed), and clears the runlist.
    def clear_runlist
      # clear the attributes
      @runlist = []
    end

    # A tracing procedure.  echo adds input to runlist then returns input.
    def echo
      lambda do |task, *inputs| 
        @runlist << inputs
        inputs
      end
    end
    
    # A tracing procedure for numeric inputs.  add_one adds the input to 
    # runlist then returns input + 1.
    def add_one
      lambda do |task, input| 
        @runlist << input
        input += 1
      end
    end
  end
end