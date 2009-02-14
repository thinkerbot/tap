require 'tap/support/audit'
require 'tap/support/joins'

module Tap
  module Support
    
    # Executable wraps objects to make them executable by App.
    module Executable
      
      # The App receiving self during enq
      attr_reader :app
      
      # The method called during _execute
      attr_reader :method_name
    
      # The block called when _execute completes
      attr_reader :on_complete_block
      
      # An array of dependency indicies that will be resolved on _execute
      attr_reader :dependencies
      
      public
      
      # Extends obj with Executable and sets up all required variables.  The
      # specified method will be called on _execute.
      def self.initialize(obj, method_name, app=App.instance, dependencies=[], &on_complete_block)
        obj.extend Executable
        obj.instance_variable_set(:@app, app)
        obj.instance_variable_set(:@method_name, method_name)
        obj.instance_variable_set(:@on_complete_block, on_complete_block)
        obj.instance_variable_set(:@dependencies, dependencies)
        obj
      end
      
      # Enqueues self to app with the inputs. The number of inputs provided
      # should match the number of inputs for the method_name method.
      def enq(*inputs)
        app.queue.enq(self, inputs)
        self
      end
      
      # Sets a block to receive the results of _execute.  Raises an error if
      # an on_complete_block is already set.  Override the existing 
      # on_complete_block by specifying override = true.
      #
      # Note: the block recieves an audited result and not the result
      # itself (see Audit for more information).
      def on_complete(override=false, &block) # :yields: _result
        unless on_complete_block == nil || override
          raise "on_complete_block already set: #{self}" 
        end
        @on_complete_block = block
        self
      end
      
      # Sets a sequence workflow pattern for the tasks; each task
      # enques the next task with it's results, starting with self.
      def sequence(*tasks, &block) # :yields: _result
        options = tasks[-1].kind_of?(Hash) ? tasks.pop : {}
        
        current_task = self
        tasks.each do |next_task|
          Join.new(options).join([current_task], [next_task], &block)
          current_task = next_task
        end
      end

      # Sets a fork workflow pattern for self; each target will enque the
      # results of self.
      def fork(*targets, &block) # :yields: _result
        options = targets[-1].kind_of?(Hash) ? targets.pop : {}
        Join.new(options).join([self], targets, &block)
      end

      # Sets a simple merge workflow pattern for the source tasks. Each 
      # source enques self with it's result; no synchronization occurs, 
      # nor are results grouped before being enqued.
      def merge(*sources, &block) # :yields: _result
        options = sources[-1].kind_of?(Hash) ? sources.pop : {}
        Join.new(options).join(sources, [self], &block)
      end

      # Sets a synchronized merge workflow for the source tasks.  Results 
      # from each source are collected and enqued as a single group to
      # self.  The collective results are not enqued until all sources
      # have completed.  See Joins::SyncMerge.
      def sync_merge(*sources, &block) # :yields: _result
        options = sources[-1].kind_of?(Hash) ? sources.pop : {}
        Joins::SyncMerge.new(options).join(sources, [self], &block)
      end

      # Sets a switch workflow pattern for self.  On complete, switch yields
      # the audited result to the block and the block should return the index
      # of the target to enque with the results. No target will be enqued if
      # the index is false or nil.  An error is raised if no target can be
      # found for the specified index. See Joins::Switch.
      def switch(*targets, &block) # :yields: _result
        options = targets[-1].kind_of?(Hash) ? targets.pop : {}
        Joins::Switch.new(options).join([self], targets, &block)
      end
      
      # Adds the dependencies to self.  Dependencies are resolved during
      # _execute through resolve_dependencies.
      def depends_on(*dependencies)
        raise ArgumentError, "cannot depend on self" if dependencies.include?(self)
        
        dependencies.each do |dependency|
          app.dependencies.register(dependency)
          self.dependencies << dependency unless self.dependencies.include?(dependency)
        end
        
        self
      end
      
      # Resolves dependencies. (See Dependency#resolve).
      def resolve_dependencies
        dependencies.each {|dependency| dependency.resolve }
        self
      end
      
      # Resets dependencies so they will be re-resolved on
      # resolve_dependencies. (See Dependency#reset).
      def reset_dependencies
        dependencies.each {|dependency| dependency.reset }
        self
      end
      
      # Auditing method call.  Resolves dependencies, executes method_name,
      # and sends the audited result to the on_complete_block (if set).
      #
      # Returns the audited result.
      def _execute(*inputs)
        resolve_dependencies
        
        previous = []
        inputs.collect! do |input| 
          if input.kind_of?(Audit) 
            previous << input
            input.value
          else
            previous << Audit.new(nil, input)
            input
          end
        end
         
        audit = Audit.new(self, send(method_name, *inputs), previous)
        if complete_block = on_complete_block || app.on_complete_block
          complete_block.call(audit)
        else 
          app.aggregator.store(audit)
        end
        
        audit
      end
      
      # Calls _execute with the inputs and returns the non-audited result.
      def execute(*inputs)
        _execute(*inputs).value
      end
      
      # Raises a TerminateError if app.state == State::TERMINATE.
      # check_terminate may be called at any time to provide a 
      # breakpoint in long-running processes.
      def check_terminate
        if app.state == App::State::TERMINATE
          raise App::TerminateError.new
        end
      end
      
    end
  end
end

# Tap extends Object with <tt>_method</tt> to generate executable methods
# that can be enqued by Tap::App and incorporated into workflows.
#
#   array = []
#   push_to_array = array._method(:push)
#
#   task = Tap::Task.new  
#   task.sequence(push_to_array)
#
#   task.enq(1).enq(2,3)
#   task.app.run
#
#   array   # => [[1],[2,3]]
#
class Object
  
  # Initializes a Tap::Support::Executable using the object returned by
  # Object#method(method_name).
  #
  # Returns nil if Object#method returns nil.
  def _method(method_name, app=Tap::App.instance)
    return nil unless m = method(method_name)
    Tap::Support::Executable.initialize(m, :call, app)
  end
end