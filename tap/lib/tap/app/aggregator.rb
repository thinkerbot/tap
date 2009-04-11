require 'monitor'

module Tap
  class App
  
    # Aggregator allows thread-safe collection of Audits, organized by
    # Audit#key.
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
        @hash = {}
      end
      
      # Clears self of all audits. Returns the existing audits as a hash
      # of (key, audits) pairs.
      def clear
        synchronize do
          current, @hash = @hash, {}
          current
        end
      end
      
      # The total number of audits recorded in self.
      def size
        synchronize { @hash.values.inject(0) {|sum, array| sum + array.length} }
      end
      
      # True if size == 0
      def empty?
        synchronize { size == 0 }
      end
      
      # Stores the Audit according to _audit.key.
      def store(_audit)
        synchronize { (@hash[_audit.key] ||= []) << _audit }
      end
      
      # Retreives all audits for the specified key.
      def retrieve(key)
        synchronize { @hash[key] }
      end
      
      # Retreives all audits for the input keys, joined as an array.
      def retrieve_all(*keys)
        synchronize do
          keys.collect {|src| @hash[src] }.flatten.compact
        end
      end
      
      # Converts self to a hash of (key, audits) pairs.
      def to_hash
        synchronize { @hash.dup }
      end
    end
  end
end