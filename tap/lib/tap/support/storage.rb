module Tap
  module Support
    
    # Storage allows thread-safe storage and retrieval of key-value pairs
    # (basically a simplified, thread-safe hash).
    #
    #   storage = Storage.new
    #   storage.store(:key, 'value')
    #   storage.fetch(:key)              # => "value"
    #   storage.to_hash                  # => {:key => 'value'}
    #
    class Storage < Monitor
      
      # Creates a new Storage.
      def initialize
        super
        @hash = {}
      end
      
      # Stores the value in self by key, overwriting the existing value.
      def store(key, value)
        synchronize { @hash[key] = value }
      end
      
      # Returns the value specified by key.
      def fetch(key)
        synchronize { @hash[key] }
      end
      
      # Removes the value specified by key and returns the result.
      def remove(key)
        synchronize { @hash.delete(key) }
      end
      
      # Returns true if self has a value for key.
      def key?(key)
        synchronize { @hash.key?(key) }
      end
      
      # Clears self of values and returns currently stored (key, value) pairs
      # as a hash.
      def clear
        synchronize do
          current, @hash = @hash, {}
          current
        end
      end
      
      # Converts self to a hash.
      def to_hash
        synchronize { @hash.dup }
      end
    end
  end
end