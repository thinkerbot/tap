module Tap
  module Support
    
    # InstanceConfiguration serves as a forwarding hash, where get and set operations
    # for config keys are send to instance methods rather than to an underlying data 
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
    # Non-config keys are simply stored in InstanceConfiguration, as if it were a hash.
    #
    #   config[:not_a_key] = 'value'
    #   config[:not_a_key]          # => 'value'
    #
    #   config.to_hash              # => {:key => 'another', :not_a_key => 'value'}
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
        
        class_config.each_map do |key, setter|
          receiver.send(setter, store.delete(key))
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
        class_config.keys.each do |key|
          store[key] = receiver.send(key)
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
        when bound? && class_config.key?(key, false)
          receiver.send(class_config.setter(key), value)
        else store[key] = value
        end
      end
      
      # Retrieves the value corresponding to the key. If bound? 
      # and the key is a class_config key, then the value is
      # obtained from the :key method on the receiver.
      def [](key)
        case 
        when bound? && class_config.key?(key, false)
          receiver.send(key)
        else store[key]
        end
      end
      
      # True if the key is assigned in self.
      def has_key?(key)
        (bound? && class_config.key?(key, false)) || store.has_key?(key) 
      end
      
      # Calls block once for each key-value pair stored in self.
      def each_pair # :yields: key, value
        class_config.keys.each do |key|
          yield(key, receiver.send(key))
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

    end
  end
end