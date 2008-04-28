module Tap
  module Support
    # Raised when an exception is raised during App#run.  All errors generated during
    # termination are collected into the RunError.
    class RunError < RuntimeError
      attr_reader :errors
  
      def initialize(errors)
        @errors = errors
        @backtrace = nil
      end
      
      #The join of all the error messages.
      def message
        lines = []
        errors.each_with_index do |error, i| 
          lines << "\nRunError [#{i}] #{error.class} #{error.message}"
        end
        lines.join + "\n"
      end
      
      #The join of all the error backtraces.
      def backtrace
        # backtrace gets called every time RunError is re-raised, leading to multiple
        # repeats of the error backtraces.  This ensures the additional backtrace 
        # information is only added once.
        return @backtrace unless @backtrace == nil
        return nil unless @backtrace = super
        
        errors.each_with_index do |error, i| 
          @backtrace [-1] += "\n\n---------------------- RunError [#{i}] ----------------------\n#{error.class} #{error.message}"
          @backtrace.concat(error.backtrace ||  ["missing backtrace"])
        end
        @backtrace
      end
    
    end
  end
end