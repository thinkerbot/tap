require 'tap/auditor/array_audit'

module Tap
  
  # Auditing middleware for a Tap::App.
  class Auditor
    
    # The application call stack
    attr_reader :stack
    
    def initialize(stack)
      @stack = stack
    end
        
    def call(node, inputs=[])
      # audit inputs if necessary
      inputs.collect! do |input| 
        if input.kind_of?(Audit) 
          input
        else
          audit_class(input).new(nil, input)
        end
      end
      
      # make an audited call if possible
      result = if false
        stack.call(node, inputs)
      else
        stack.call(node, inputs.collect {|input| input.value })
      end
      
      audit_class(result).new(node, result, inputs)
    end
    
    protected
    
    # helper to look up the appropriate audit class for the input
    def audit_class(input) # :nodoc:
      if input.respond_to?(:to_ary)
        ArrayAudit
      else  
        Audit
      end
    end
    
  end
end