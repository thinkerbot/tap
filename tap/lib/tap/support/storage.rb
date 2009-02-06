module Tap
  module Support
    
    # Storage allows thread-safe storage and retrieval of key-value pairs
    # (basically a simplified, thread-safe hash).
    #
    #   storage = Storage.new
    #   storage[:key] = 'value'
    #   storage[:key]                          # => "value"
    #   storage.to_hash                        # => {:key => 'value'}
    #
    # Storage provides convenience methods for storing and fetching results
    # such as randomly generated keys:
    #
    #   id = storage.store('VALUE')
    #   storage[id]                            # => 'VALUE'
    #
    # And fetching with a default value:
    #
    #   storage.has_key?(:unknown)             # => false
    #   storage.fetch(:unknown) { 'default' }  # => 'default'
    #   storage[:unknown]                      # => 'default'
    #
    class Storage < Monitor
      
      # Creates a new Storage.
      def initialize
        super
        @hash = {}
      end
      
      # Stores the value in self by key, overwriting the existing value.
      def []=(key, value)
        synchronize { @hash[key] = value }
      end
      
      # Returns the value specified by key.
      def [](key)
        synchronize { @hash[key] }
      end
      
      # Stores value in self by a random integer key and returns the key.
      def store(value)
        synchronize do
          # generate a random key
          key = random_key(@hash.length)
          while @hash.has_key?(key)
            key = random_key(@hash.length)
          end
          
          @hash[key] = value
          key
        end
      end
      
      # Fetches the value for key.  If no value has been stored for key and a
      # block is given, fetch evaluates block, stores and returns the result.
      def fetch(key)
        synchronize do
          case
          when @hash.has_key?(key) 
            @hash[key]
          when block_given?
            self[key] = yield
          else
            nil
          end
        end
      end
      
      # Removes the value specified by key and returns the result.
      def remove(key)
        synchronize { @hash.delete(key) }
      end
      
      # Returns true if self has a value for key.
      def has_key?(key)
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
      
      protected
      
      # Generates a random integer key.
      def random_key(length) # :nodoc:
        length = 1 if length < 1
        rand(length * 10000)
      end
    end
  end
end