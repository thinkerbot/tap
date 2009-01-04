module Tap
  module Support
  
    # Aggregator allows thread-safe collection of Audits, organized
    # by Audit#key.
    #
    #   a = Audit.new(:key, 'a')
    #   b = Audit.new(:key, 'b')
    #
    #   agg = Aggregator.new
    #   agg.store(a)
    #   agg.store(b)
    #   agg.retrieve(:key)             # => [a, b]
    #
    class Aggregator < Monitor
      
      # Creates a new Aggregator.
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
      
      # Stores the Audit according to _result.key
      def store(_result)
        synchronize { (hash[_result.key] ||= []) << _result }
      end
      
      # Retreives all aggregated audits for the specified source.
      def retrieve(source)
        synchronize { hash[source] }
      end
      
      # Retreives all audits for the input sources, joined as an array.
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
      
      attr_accessor :hash # :nodoc:
    end
  end
end