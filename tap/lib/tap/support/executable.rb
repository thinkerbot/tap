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
      
      # The batch for self
      attr_reader :batch
      
      public
      
      # Extends obj with Executable and sets up all required variables.  The
      # specified method will be called on _execute.
      def self.initialize(obj, method_name, app=App.instance, batch=[], dependencies=[], &on_complete_block)
        obj.extend Executable
        obj.instance_variable_set(:@app, app)
        obj.instance_variable_set(:@method_name, method_name)
        obj.instance_variable_set(:@on_complete_block, on_complete_block)
        obj.instance_variable_set(:@dependencies, dependencies)
        obj.instance_variable_set(:@batch, batch)
        batch << obj
        
        obj
      end
      
      # Initializes a new batch object and adds the object to batch. The object
      # will be a duplicate of self.  
      #
      # Note this method can raise an error for objects that don't support dup, 
      # notably Method objects generated by Object#_method.
      def initialize_batch_obj
        obj = self.dup
        
        if obj.kind_of?(Executable)
          batch << obj
          obj
        else
          Executable.initialize(obj, method_name, app, batch, dependencies, &on_complete_block)
        end
      end
      
      # Returns true if the batch size is greater than one 
      # (the one is assumed to be self).  
      def batched?
        batch.length > 1
      end

      # Returns the index of self in batch.
      def batch_index
        batch.index(self)
      end
      
      # Merges the batches for self and the specified Executables,
      # removing duplicates.
      #
      #   class BatchExecutable
      #     include Tap::Support::Executable
      #     def initialize(batch=[])
      #       @batch = batch
      #       batch << self
      #     end
      #   end
      #
      #   b1 = BatchExecutable.new
      #   b2 = BatchExecutable.new
      #   b3 = BatchExecutable.new
      #
      #   b1.batch_with(b2, b3)
      #   b1.batch                   # => [b1, b2, b3]
      #   b3.batch                   # => [b1, b2, b3]
      #
      # Note that batch_with is not recursive (ie it does not 
      # merge the batches of each member in the batch):
      #
      #   b4 = BatchExecutable.new
      #   b4.batch_with(b3)   
      #            
      #   b4.batch                   # => [b4, b1, b2, b3]
      #   b3.batch                   # => [b4, b1, b2, b3]
      #   b2.batch                   # => [b1, b2, b3]
      #   b1.batch                   # => [b1, b2, b3]
      #
      # However it does affect all objects that share the same
      # underlying batch:
      #
      #   b5 = BatchExecutable.new(b1.batch)
      #   b6 = BatchExecutable.new
      #
      #   b5.batch.object_id         # => b1.batch.object_id
      #   b5.batch                   # => [b1, b2, b3, b5]
      #
      #   b5.batch_with(b6)
      #
      #   b5.batch                   # => [b1, b2, b3, b5, b6]
      #   b1.batch                   # => [b1, b2, b3, b5, b6]
      #
      # Returns self.
      def batch_with(*executables)
        batches = [batch] + executables.collect {|executable| executable.batch }
        batches.uniq!
        
        merged = []
        batches.each do |batch| 
          merged.concat(batch)
          batch.clear
        end
        
        merged.uniq!
        batches.each {|batch| batch.concat(merged) }
        self
      end
      
      # Enqueues each member of batch (and implicitly self) to app with the
      # inputs. The number of inputs provided should match the number of
      # inputs for the method_name method.
      def enq(*inputs)
        batch.each do |executable| 
          executable.unbatched_enq(*inputs)
        end
        self
      end
      
      # Like enq, but only enques self.
      def unbatched_enq(*inputs)
        app.queue.enq(self, inputs)
        self
      end
      
      # Sets a block to receive the results of _execute for each member of 
      # batch (and implicitly self).  Raises an error if on_complete_block
      # is already set within the batch.  Override the existing 
      # on_complete_block by specifying override = true.
      #
      # Note: the block recieves an audited result and not the result
      # itself (see Audit for more information).
      def on_complete(override=false, &block) # :yields: _result
        batch.each do |executable| 
          executable.unbatched_on_complete(override, &block)
        end
        self
      end
      
      # Like on_complete, but only sets the on_complete_block for self.
      def unbatched_on_complete(override=false, &block) # :yields: _result
        unless on_complete_block == nil || override
          raise "on_complete_block already set: #{self}" 
        end
        @on_complete_block = block
        self
      end
      
      # Sets a sequence workflow pattern for the tasks; each task
      # enques the next task with it's results, starting with self.  
      # See Joins::Sequence.
      def sequence(*tasks, &block) # :yields: _result
        Joins::Sequence.join(self, tasks, &block)
      end

      # Sets a fork workflow pattern for self; each target
      # will enque the results of self.  See Joins::Fork.
      def fork(*targets, &block) # :yields: _result
        Joins::Fork.join(self, targets, &block)
      end

      # Sets a simple merge workflow pattern for the source tasks. Each 
      # source enques self with it's result; no synchronization occurs, 
      # nor are results grouped before being enqued.  See Joins::Merge.
      def merge(*sources, &block) # :yields: _result
        Joins::Merge.join(self, sources, &block)
      end

      # Sets a synchronized merge workflow for the source tasks.  Results 
      # from each source are collected and enqued as a single group to
      # self.  The collective results are not enqued until all sources
      # have completed.  See Joins::SyncMerge.
      #
      # Raises an error if a source returns twice before the target is enqued.
      def sync_merge(*sources, &block) # :yields: _result
        Joins::SyncMerge.join(self, sources, &block)
      end

      # Sets a switch workflow pattern for self.  When _execute completes, 
      # switch yields the audited result to the block and the block should
      # return the index of the target to enque with the results. No target
      # will be enqued if the index is false or nil.  An error is raised if
      # no target can be found for the specified index. See Joins::Switch.
      def switch(*targets, &block) # :yields: _result
        Joins::Switch.join(self, targets, &block)
      end
      
      # Adds the dependency to each member in batch (and implicitly self).
      # The dependency will be resolved with the input arguments during 
      # _execute, using resolve_dependencies.
      def depends_on(*dependencies)
        batch.each do |e| 
          e.unbatched_depends_on(*dependencies)
        end
        self
      end
      
      # Like depends_on, but only adds the dependency to self.
      def unbatched_depends_on(*dependencies)
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
        on_complete_block ? on_complete_block.call(audit) : app.aggregator.store(audit)
        
        audit
      end
      
      # Calls _execute with the inputs and returns the non-audited result.
      # Execute is not a batched method.
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