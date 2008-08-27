module Tap
  module Support
    module Dependency
      def self.extended(base)
        base.instance_variable_set(:@results, {})
      end
    
      attr_reader :results
      
      def resolved?(args)
        @results.has_key?(args)
      end
    
      def resolve(args)
        resolved?(args) ? @results[args] : @results[args] = execute(*args)
      end
    end
  end
end