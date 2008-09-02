require 'tap/support/audit'

module Tap
  module Support
    
    # Executable wraps methods to make them executable by App.  Methods are 
    # wrapped by extending the object that receives them; the easiest way
    # to make an object executable is to use Object#_method.
    module Executable
      
      # The method called when an Executable is executed via _execute
      attr_reader :_method_name
    
      # Stores the on complete block.
      attr_reader :on_complete_block
      
      attr_reader :dependencies
      
      public
      
      # Extends obj with Executable and sets up all required variables.  The
      # specified method will be called on _execute.
      def self.initialize(obj, method_name, &on_complete_block)
        obj.extend Executable
        obj.instance_variable_set(:@_method_name, method_name)
        obj.instance_variable_set(:@on_complete_block, on_complete_block)
        obj.instance_variable_set(:@dependencies, [])
        obj
      end

      def self.clear_dependencies
        @registry = []
        @results = []
      end
      
      def self.registry
        @registry
      end
      
      def self.results
        @results
      end
      
      def self.index(instance, args)
        @registry.each_with_index do |entry, index|
          return index if entry[0] == instance && entry[1] == args
        end
        nil
      end
      
      def self.resolved?(index)
        @results[index] != nil
      end
      
      def self.resolve(indicies)
        indicies.each do |index|
          next if @results[index]
          instance, inputs = @registry[index]
          @results[index] = instance._execute(*inputs)
        end
      end

      def self.reset(indicies)
        indicies.each {|index| @results[index] = nil }
      end
      
      def self.register(instance, args)
        if existing = index(instance, args)
          return existing 
        end
        
        @registry << [instance, args]
        @registry.length - 1
      end
      
      clear_dependencies
      
      # Sets a block to receive the results of _execute.  Raises an error 
      # if an on_complete block is already set.  Override an existing
      # on_complete block by specifying override = true.
      #
      # Note the block recieves an audited result and not
      # the result itself (see Audit for more information).
      def on_complete(override=false, &block) # :yields: _result
        unless on_complete_block == nil || override
          raise "on_complete_block already set: #{self}" 
        end
        @on_complete_block = block
      end
      
      # Adds the dependency to self, making self dependent on the dependency.
      # The dependency will be called with the input arguments during 
      # resolve_dependencies.
      def depends_on(dependency, *inputs)
        raise ArgumentError, "not an Executable: #{dependency}" unless dependency.kind_of?(Executable)
        raise ArgumentError, "cannot depend on self" if dependency == self
        
        index = Executable.register(dependency, inputs)
        dependencies << index unless dependencies.include?(index)
        index
      end
      
      # Resolves dependencies by calling dependency.resolve with
      # the dependency arguments.
      def resolve_dependencies
        Executable.resolve(dependencies)
        self
      end
      
      def reset_dependencies
        Executable.reset(dependencies)
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
        on_complete_block.call(audit) if on_complete_block
      
        audit
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
#   task.app.sequence(task, push_to_array)
#
#   task.enq(1).enq(2,3)
#   task.app.run
#
#   array   # => [[1],[2,3]]
#
class Object
  
  # Initializes a Tap::Support::Executable using the Method returned by
  # Object#method(method_name), setting multithread and the on_complete 
  # block as specified.  Returns nil if Object#method returns nil.
  def _method(method_name, &on_complete_block) # :yields:  _result
    return nil unless m = method(method_name)
    Tap::Support::Executable.initialize(m, :call, &on_complete_block)
  end
end