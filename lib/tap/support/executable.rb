require 'tap/app'
require 'tap/support/audit'
require 'tap/support/dependable'

module Tap
  module Support
    
    # Executable wraps methods to make them executable by App.  Methods are 
    # wrapped by extending the object that receives them; the easiest way
    # to make an object executable is to use Object#_method.
    module Executable
      extend Dependable
  
      # The application the Executable belongs to.
      attr_reader :app
      
      # The method called when an Executable is executed via _execute
      attr_reader :_method_name
    
      # Stores the on complete block
      attr_reader :on_complete_block
      
      # An array of dependency indexes that will be resolved on _execute
      attr_reader :dependencies
      
      # The batch for the Executable.
      attr_reader :batch
      
      public
      
      # Extends obj with Executable and sets up all required variables.  The
      # specified method will be called on _execute.
      def self.initialize(obj, method_name, app=App.instance, batch=[], &on_complete_block)
        obj.extend Executable
        obj.instance_variable_set(:@app, app)
        obj.instance_variable_set(:@_method_name, method_name)
        obj.instance_variable_set(:@on_complete_block, on_complete_block)
        obj.instance_variable_set(:@dependencies, [])
        obj.instance_variable_set(:@batch, batch)
        batch << obj
        
        obj
      end
      
      # Adds the dependency to self, making self dependent on the dependency.
      # The dependency will be resolved by calling dependency._execute with 
      # the input arguments during resolve_dependencies.
      def depends_on(dependency, *inputs)
        raise ArgumentError, "not an Executable: #{dependency}" unless dependency.kind_of?(Executable)
        raise ArgumentError, "cannot depend on self" if dependency == self
        
        index = Executable.register(dependency, inputs)
        dependencies << index unless dependencies.include?(index)
        index
      end
      
      # Resolves dependencies by calling dependency._execute with
      # the dependency arguments.  (See Dependable#resolve).
      def resolve_dependencies
        Executable.resolve(dependencies)
        self
      end
      
      # Resets dependencies so they will be re-resolved on resolve_dependencies.
      # (See Dependable#reset).
      def reset_dependencies
        Executable.reset(dependencies)
        self
      end
      
      # Returns true if the batch size is greater than one 
      # (the one being self).  
      def batched?
        batch.length > 1
      end

      # Returns the index of the self in batch.
      def batch_index
        batch.index(self)
      end
      
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
        merged
      end
      
      def unbatched_enq(*inputs)
        app.queue.enq(self, inputs)
      end
      
      # Enqueues self and self.batch to app with the inputs.  
      # The number of inputs provided should match the number 
      # of inputs specified by the arity of the _method_name method.
      def enq(*inputs)
        batch.each {|t| t.unbatched_enq(*inputs) }
        self
      end
      
      def unbatched_on_complete(override=false, &block) # :yields: _result
        unless on_complete_block == nil || override
          raise "on_complete_block already set: #{self}" 
        end
        @on_complete_block = block
      end
      
      # Sets a block to receive the results of _execute.  Raises an error 
      # if an on_complete block is already set.  Override an existing
      # on_complete block by specifying override = true.
      #
      # Note the block recieves an audited result and not
      # the result itself (see Audit for more information).
      def on_complete(override=false, &block) # :yields: _result
        batch.each {|t| t.unbatched_on_complete(override, &block) }
        self
      end
      
      # Convenience method, equivalent to:
      #   self.app.sequence([self] + tasks)
      def sequence(*tasks)
        app.sequence([self] + tasks)
      end

      # Convenience method, equivalent to:
      #   self.app.fork(self, targets)
      def fork(*targets)
        app.fork(self, targets)
      end

      # Convenience method, equivalent to:
      #   self.app.merge(self, sources)
      def merge(*sources)
        app.merge(self, sources)
      end

      # Convenience method, equivalent to:
      #   self.app.sync_merge(self, sources)
      def sync_merge(*sources)
        app.sync_merge(self, sources)
      end

      # Convenience method, equivalent to:
      #   self.app.switch(self, targets, &block)
      def switch(*targets, &block)
        app.switch(self, targets, &block)
      end
      
      # Auditing method call.  Executes _method_name for self, but audits 
      # the result. Sends the audited result to the on_complete_block if set.
      #
      # Audits are initialized in the follwing manner:
      # no inputs:: create a new, empty Audit.  The first value of the audit
      #             will be the result of call
      # one input:: forks the input if it is an audit, otherwise initializes
      #             a new audit using the input
      # multiple inputs:: merges the inputs into a new Audit.
      #
      # Dependencies are resolved using resolve_dependencies before
      # _method_name is executed.
      def _execute(*inputs)
        resolve_dependencies
        
        audit = case inputs.length
        when 0 then Audit.new
        when 1 
          audit = inputs.first
          if audit.kind_of?(Audit) 
            inputs = [audit._current]
            audit._fork
          else
            Audit.new(audit)
          end 
        else
          sources = []
          inputs.collect! do |input| 
            if input.kind_of?(Audit) 
              sources << input._fork
              input._current
            else
              sources << nil
              input
            end
          end
          Audit.new(inputs, sources)
        end
      
        audit._record(self, send(_method_name, *inputs))
        on_complete_block ? on_complete_block.call(audit) : app.aggregator.store(audit)
        
        audit
      end
      
      def inspect
        "#<#{self.class.to_s}:#{object_id} _method: #{_method_name} batch_length: #{batch.length} app: #{app}>"
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
  
  # Initializes a Tap::Support::Executable using the Method returned by
  # Object#method(method_name), setting the on_complete block as specified.  
  # Returns nil if Object#method returns nil.
  def _method(method_name, app=Tap::App.instance, &on_complete_block) # :yields:  _result
    return nil unless m = method(method_name)
    Tap::Support::Executable.initialize(m, :call, app, &on_complete_block)
  end
end