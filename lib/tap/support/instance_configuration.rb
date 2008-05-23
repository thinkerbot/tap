module Tap
  module Support
    
    # InstanceConfiguration serves as a forwarding hash, where get and set operations
    # for configurations are sent to instance methods rather than to an underlying data 
    # store.  
    #
    #   class Sample
    #     attr_accessor :key
    #   end
    #   sample = Sample.new
    #
    #   class_config = ClassConfiguration.new(Sample)
    #   class_config.add(:key)
    #
    #   config = InstanceConfiguration.new(class_config)
    #   config.bind(sample)
    #
    #   sample.key = 'value'
    #   config[:key]                # => 'value'
    #
    #   config[:key] = 'another'
    #   sample.key                  # => 'another'
    #
    # Non-config keys are simply stored as in a Hash:
    #
    #   config[:not_a_key] = 'value'
    #   config[:not_a_key]          # => 'value'
    #
    #   config.to_hash              # => {:key => 'another', :not_a_key => 'value'}
    #
    # See Tap::Support::Configurable for more details.
    #
    class InstanceConfiguration
      
      # The bound receiver
      attr_reader :receiver
      
      # The underlying data store for non-config keys
      attr_reader :store
      
      # The ClassConfiguration specifying config keys
      attr_reader :class_config
      
      def initialize(class_config, receiver=nil)
        @receiver = receiver
        @store = {}
        @class_config = class_config
      end
      
      # Binds self to the specified receiver.  Mapped keys are
      # removed from store and sent to their setter method on 
      # receiver.
      def bind(receiver)
        raise ArgumentError.new("receiver cannot be nil") if receiver == nil
        
        class_config.each_pair do |key, config|
          receiver.send(config.setter, store.delete(key))
        end
        @receiver = receiver
        
        self
      end
      
      # Returns true if self is bound to a receiver
      def bound?
        receiver != nil
      end
      
      # Unbinds self from the specified receiver.  Mapped values
      # are stored in store.  Returns the unbound receiver.
      def unbind
        class_config.each_pair do |key, config|
          store[key] = receiver.send(config.getter)
        end
        r = receiver
        @receiver = nil
        
        r
      end
      
      # Duplicates self, returning an unbound InstanceConfiguration.
      def dup
        duplicate = super()
        duplicate.instance_variable_set(:@receiver, nil)
        duplicate.instance_variable_set(:@store, @store.dup)
        duplicate
      end
      
      # Associates the value the key.  If bound? and the key
      # is a class_config key, then the value will be forwarded
      # to the class_config.setter method on the receiver.
      def []=(key, value)
        case 
        when bound? && config = class_config.map[key.to_sym]
          receiver.send(config.setter, value)
        else store[key] = value
        end
      end
      
      # Retrieves the value corresponding to the key. If bound? 
      # and the key is a class_config key, then the value is
      # obtained from the :key method on the receiver.
      def [](key)
        case 
        when bound? && config = class_config.map[key.to_sym]
          receiver.send(config.getter)
        else store[key]
        end
      end
      
      # True if the key is assigned in self.
      def has_key?(key)
        (bound? && class_config.key?(key)) || store.has_key?(key) 
      end
      
      # Calls block once for each key-value pair stored in self.
      def each_pair # :yields: key, value
        class_config.each_pair do |key, config|
          yield(key, receiver.send(config.getter))
        end if bound?
        
        store.each_pair do |key, value|
          yield(key, value)
        end
      end
      
      # Equal if the to_hash values of self and another are equal.
      def ==(another)
        to_hash == another.to_hash
      end
      
      # Returns self as a hash. 
      def to_hash
        hash = store.dup
        class_config.keys.each do |key|
          hash[key] = self[key]
        end if bound?
        hash
      end
      
      # Overrides default inspect to show the to_hash values.
      def inspect
        "#<#{self.class}:#{object_id} to_hash=#{to_hash.inspect}>"
      end
    end
  end
end