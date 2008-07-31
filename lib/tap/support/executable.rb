require 'tap/support/audit'

module Tap
  module Support
    # Executable wraps methods to make them executable by App.
    module Executable
      
      # The method called when an Executable is executed via _execute
      attr_reader :_method_name
    
      # Indicates whether or not to call in multithread mode.  Default false.
      attr_accessor :multithread

      # Stores the on complete block.  Default is Executable.default_on_complete_block.
      attr_reader :on_complete_block
    
      public

      def self.initialize(obj, method_name, multithread=false, &on_complete_block)
        obj.extend Executable
        obj.instance_variable_set(:@_method_name, method_name)
        obj.instance_variable_set(:@multithread, multithread)
        obj.instance_variable_set(:@on_complete_block, on_complete_block)
        obj
      end
    
      # Sets a block to receive the results of _call.  Raises an error 
      # if on_complete_block is already set, unless override = true.
      #
      # Note the block recieves an audited result and not
      # the result itself (see Audit for more information).
      def on_complete(override=false, &block) # :yields: _result
        unless on_complete_block == nil || override
          raise "on_complete_block already set: #{self}" 
        end
        @on_complete_block = block
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
      def _execute(*inputs)
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

# Tap extends Object with a convenience method to generate methods
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
  def _method(method_name, multithread=false, &on_complete_block) # :yields:  _result
    return nil unless m = method(method_name)
    Tap::Support::Executable.initialize(m, :call, multithread, &on_complete_block)
  end
end