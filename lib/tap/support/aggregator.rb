module Tap
  module Support
  
    # Aggregator allows thread-safe collection of Audits, organized
    # by Audit#_current_source.    
    class Aggregator < Monitor

      def initialize
        super
        clear
      end
      
      # Clears self of all audits.
      def clear
        synchronize { self.hash = Hash.new }
      end
      
      # The total number of audits recorded in self.
      def size
        synchronize { hash.values.inject(0) {|sum, array| sum + array.length} }
      end
      
      # True if size == 0
      def empty?
        synchronize { hash.empty? }
      end
      
      # Stores the Audit according to _result._current_source
      def store(_result)
        synchronize { (hash[_result._current_source] ||= []) << _result }
      end
      
      # Retreives all aggregated audits for the specified source.
      def retrieve(source)
        synchronize { hash[source] }
      end
      
      # Retreives all audits for the input sources, joined into an array.
      def retrieve_all(*sources)
        synchronize do
          sources.collect {|src| hash[src] }.flatten.compact
        end
      end
      
      # Converts self to a hash of (source, audits) pairs.
      def to_hash
        hash.dup
      end
      
      protected
      
      attr_accessor :hash
    end
  end
end