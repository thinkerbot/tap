require 'tap/support/audit'

module Tap
  module Support
    
    # Executable wraps methods to make them executable by App.  Methods are 
    # wrapped by extending the object that receives them; the easiest way
    # to make an object executable is to use Object#_method.
    module Executable
      
      # The Tap::App the Executable belongs to.
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
      def self.initialize(obj, method_name, app=App.instance, batch=[])
        obj.extend Executable
        obj.instance_variable_set(:@app, app)
        obj.instance_variable_set(:@_method_name, method_name)
        obj.instance_variable_set(:@on_complete_block, nil)
        obj.instance_variable_set(:@dependencies, [])
        obj.instance_variable_set(:@batch, batch)
        batch << obj
        
        obj
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
      
      # Enqueues self and self.batch to app with the inputs. The number 
      # of inputs provided should match the number of inputs specified 
      # by the arity of the _method_name method.
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
      
      # Sets a block to receive the results of _execute.  Raises an
      # error if an on_complete block is already set.  Override an
      # existing on_complete block by specifying override = true.
      #
      # Note the block recieves an audited result and not
      # the result itself (see Audit for more information).
      def on_complete(override=false, &block) # :yields: _result
        batch.each do |executable| 
          executable.unbatched_on_complete(override, &block)
        end
        self
      end
      
      # Like on_complete, but only sets on_complete_block for self.
      def unbatched_on_complete(override=false, &block) # :yields: _result
        unless on_complete_block == nil || override
          raise "on_complete_block already set: #{self}" 
        end
        @on_complete_block = block
        self
      end
      
      # Sets a sequence workflow pattern for the tasks; each task will enque 
      # the next task with it's results.
      #
      # Notes:
      # - Batched tasks will have the pattern set for each task in the batch 
      # - The current audited results are yielded to the block, if given, 
      #   before the next task is enqued.
      # - Executables may provided as well as tasks.
      def sequence(*tasks) # :yields: _result
        current_task = self
        tasks.each do |next_task|
          # simply pass results from one task to the next.  
          current_task.on_complete do |_result| 
            yield(_result) if block_given?
            next_task.enq(_result)
          end
          current_task = next_task
        end
      end

      # Sets a fork workflow pattern for the source task; each target
      # will enque the results of source.
      #
      # Notes:
      # - Batched tasks will have the pattern set for each task in the batch 
      # - The current audited results are yielded to the block, if given, 
      #   before the next task is enqued.
      # - Executables may provided as well as tasks.
      def fork(*targets) # :yields: _result
        on_complete do |_result|
          targets.each do |target| 
            yield(_result) if block_given?
            target.enq(_result)
          end
        end
      end

      # Sets a simple merge workflow pattern for the source tasks. Each source
      # enques target with it's result; no synchronization occurs, nor are 
      # results grouped before being sent to the target.
      #
      # Notes:
      # - Batched tasks will have the pattern set for each task in the batch 
      # - The current audited results are yielded to the block, if given, 
      #   before the next task is enqued.
      # - Executables may provided as well as tasks.
      def merge(*sources) # :yields: _result
        sources.each do |source|
          # merging can use the existing audit trails... each distinct 
          # input is getting sent to one place (the target)
          source.on_complete do |_result| 
            yield(_result) if block_given?
            enq(_result)
          end
        end
      end

      # Sets a synchronized merge workflow for the source tasks.  Results from
      # each source task are collected and enqued as a single group to the target. 
      # The target is not enqued until all sources have completed.  Raises an
      # error if a source returns twice before the target is enqued.
      #
      # Notes:
      # - Batched tasks will have the pattern set for each task in the batch 
      # - The current audited results are yielded to the block, if given, 
      #   before the next task is enqued.
      # - Executables may provided as well as tasks.
      #
      #-- TODO: add notes on testing and the way results are received
      # (ie as a single object)
      def sync_merge(*sources) # :yields: _result
        group = Array.new(sources.length, nil)
        sources.each_with_index do |source, index|
          batch_map = Hash.new(0)
          source.batch.each_with_index {|obj, i| batch_map[obj] = i }
          batch_length = source.batch.length

          group[index] = Array.new(batch_length, nil)

          source.on_complete do |_result|
            batch_index = batch_map[_result._current_source]

            if group[index][batch_index] != nil
              raise "sync_merge collision... already got a result for #{_result._current_source}"
            end

            group[index][batch_index] = _result

            unless group.flatten.include?(nil)
              Support::Combinator.new(*group).each do |*combination|
                # merge the source audits
                _group_result = Support::Audit.merge(*combination)

                yield(_group_result) if block_given?
                enq(_group_result)
              end

              # reset the group array
              group.collect! {|i| nil }
            end 
          end
        end
      end

      # Sets a choice workflow pattern for the source task.  When the
      # source task completes, switch yields the audited result to the 
      # block which then returns the index of the target to enque with 
      # the results. No target will be enqued if the index is false or 
      # nil; an error is raised if no target can be found for the 
      # specified index.
      #
      # Notes:
      # - Batched tasks will have the pattern set for each task in the batch 
      # - The current audited results are yielded to the block, if given, 
      #   before the next task is enqued.
      # - Executables may provided as well as tasks.
      def switch(*targets) # :yields: _result
        on_complete do |_result| 
          if index = yield(_result)        
            unless target = targets[index] 
              raise "no switch target for index: #{index}"
            end

            target.enq(_result)
          else
            app.aggregator.store(_result)
          end
        end
      end
      
      def unbatched_depends_on(dependency, *inputs)
        raise ArgumentError, "not an Executable: #{dependency}" unless dependency.kind_of?(Executable)
        raise ArgumentError, "cannot depend on self" if dependency == self
        
        index = app.dependencies.register(dependency, inputs)
        dependencies << index unless dependencies.include?(index)
        index
      end
      
      # Adds the dependency to self, making self dependent on the dependency.
      # The dependency will be resolved by calling dependency._execute with 
      # the input arguments during resolve_dependencies.
      def depends_on(dependency, *inputs)
        index = unbatched_depends_on(dependency, *inputs)
        batch.each do |e| 
          e.dependencies << index unless e.dependencies.include?(index)
        end
        index
      end
      
      # Resolves dependencies by calling dependency._execute with
      # the dependency arguments.  (See Dependable#resolve).
      def resolve_dependencies
        app.dependencies.resolve(dependencies)
        self
      end
      
      # Resets dependencies so they will be re-resolved on resolve_dependencies.
      # (See Dependable#reset).
      def reset_dependencies
        app.dependencies.reset(dependencies)
        self
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
  def _method(method_name, app=Tap::App.instance) # :yields:  _result
    return nil unless m = method(method_name)
    Tap::Support::Executable.initialize(m, :call, app)
  end
end