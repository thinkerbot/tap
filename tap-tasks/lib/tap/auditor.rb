require 'tap/auditor/array_audit'

module Tap
  
  # :startdoc::middleware
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
          Auditor.audit(nil, input)
        end
      end
      
      # make an audited call if possible
      result = if false
        stack.call(node, inputs)
      else
        stack.call(node, inputs.collect {|input| input.value })
      end
      
      Auditor.audit(node, result, inputs)
    end
  end
end