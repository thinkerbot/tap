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
    # Non-config keys are simply stored:
    #
    #   config[:not_a_key] = 'value'
    #   config[:not_a_key]          # => 'value'
    #
    #   config.store                # => {:not_a_key => 'value'}
    #   config.to_hash              # => {:key => 'another', :not_a_key => 'value'}
    #
    class InstanceConfiguration
      
      # The bound receiver
      attr_reader :receiver
      
      # The underlying data store for non-config keys
      attr_reader :store
      
      # The ClassConfiguration specifying config keys
      attr_reader :class_config
      
      def initialize(class_config, receiver=nil, store={})
        @receiver = receiver
        @store = store
        @class_config = class_config
      end
      
      # Updates self to ensure that each class_config key
      # has a value in self; the config.default value is
      # set if a value does not already exist.
      #
      # Returns self.
      def update(class_config=self.class_config)
        class_config.each_pair do |key, config|
          self[key] ||= config.default
        end
        self
      end
      
      # Binds self to the specified receiver.  Mapped keys are
      # removed from store and sent to their writer method on 
      # receiver.
      def bind(receiver)
        raise "already bound to: #{@receiver}" if bound?
        raise ArgumentError, "receiver cannot be nil" if receiver == nil
        
        class_config.each_pair do |key, config|
          receiver.send(config.writer, store.delete(key)) if config.writer
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
          store[key] = receiver.send(config.reader) if config.reader
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
      # to the config.writer method on the receiver.
      def []=(key, value)
        case 
        when bound? && config = class_config.map[key.to_sym]
          config.writer ? receiver.send(config.writer, value) : store[key] = value
        else store[key] = value
        end
      end
      
      # Retrieves the value corresponding to the key. If bound? 
      # and the key is a class_config key, then the value is
      # obtained from the config.reader method on the receiver.
      def [](key)
        case 
        when bound? && config = class_config.map[key.to_sym]
          config.reader ? receiver.send(config.reader) : store[key]
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
          yield(key, receiver.send(config.reader)) if config.reader
        end if bound?
        
        store.each_pair do |key, value|
          yield(key, value)
        end
      end
      
      # Equal if the to_hash values of self and another are equal.
      def ==(another)
        another.respond_to?(:to_hash) && to_hash == another.to_hash
      end
      
      # Returns self as a hash. 
      def to_hash
        hash = store.dup
        class_config.keys.each do |key|
          hash[key] = self[key]
        end if bound?
        hash
      end
      
      def to_yaml(opts)
        hash = {}
        store.each_pair do |key, value|
          hash[key.to_s] = value
        end
        
        class_config.each_pair do |key, config|
          hash[key.to_s] = bound? ? self[key] : config.default
        end
        
        hash.to_yaml(opts)
      end
      
      # Overrides default inspect to show the to_hash values.
      def inspect
        "#<#{self.class}:#{object_id} to_hash=#{to_hash.inspect}>"
      end
    end
  end
end