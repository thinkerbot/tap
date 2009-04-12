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
    #   agg.audits(:key)             # => [a, b]
    #
    class Aggregator < Monitor
      
      # The App calling self (set by App during execute, required by API)
      attr_accessor :app
      
      # Creates a new Aggregator.
      def initialize
        super
        @hash = {}
        @app = nil
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
        call(_audit)
      end
      
      # Alias for store.
      def call(_audit)
        synchronize { (@hash[_audit.key] ||= []) << _audit }
      end
      
      # Retreives all audits for the input keys, joined as an array.
      def audits(*keys)
        synchronize do
          keys = @hash.keys if keys.empty?
          keys.collect {|src| @hash[src] }.flatten.compact
        end
      end
      
      def results(*keys)
        audits(*keys).collect {|_audit| _audit.value }
      end
      
      # Converts self to a hash of (key, audits) pairs.
      def to_hash
        synchronize { @hash.dup }
      end
    end
  end
end