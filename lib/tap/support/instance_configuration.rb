module Tap
  module Support
    class InstanceConfiguration
      
      attr_reader :receiver, :store, :class_config
      
      def initialize(class_config)
        @class_config = class_config
        @store = {}
      end
      
      # Binds config to the specified receiver. 
      def bind(receiver)
        raise ArgumentError.new("receiver cannot be nil") if receiver == nil
        
        class_config.map.each_pair do |key, setter|
          receiver.send(setter, store.delete(key))
        end
        @receiver = receiver
        
        self
      end
      
      # Returns true if self is bound to a receiver
      def bound?
        receiver != nil
      end
      
      def unbind
        class_config.map.each_pair do |key, setter|
          store[key] = receiver.send(key)
        end
        @receiver = nil
      end
      
      # Duplicates self, returning an unbound InstanceConfiguration.
      def dup
        duplicate = super()
        duplicate.instance_variable_set(:@receiver, nil)
        duplicate.instance_variable_set(:@store, @store.dup)
        duplicate
      end
      
      def []=(key, value)
        case 
        when bound? && class_config.mapped?(key)
          receiver.send(class_config.map_setter(key), value)
        else store[key] = value
        end
      end
      
      def [](key)
        case 
        when bound? && class_config.mapped?(key)
          receiver.send(key)
        else store[key]
        end
      end
      
      
      def has_key?(key)
        store.has_key?(key)  
      end
      
      def each_pair
        if bound?
          
        end
        
        store.each_pair do |key, value|
          next if class_config.mapped?(key)
          yield(key, value)
        end
      end
      
      # Equal if the to_hash values of self and another are equal.
      def ==(another)
        to_hash == another.to_hash
      end
      
      # Returns self as a hash.  If bound, the mapped values for the 
      # receiver will be associated with the mapped keys.
      def to_hash
        hash = store.dup
        class_config.mapped_keys.each do |key|
          hash[key] = self[key]
        end if bound?
        hash
      end

      def merge(overrides={}, symbolize=true)
        overrides.each_pair do |key, value|
          key = key.to_sym if symbolize
          self[key] = value
        end
      end
      
      # 
      # def merge!
      # end
      # 
      # def reverse_merge
      # end
      # 
      # def reverse_merge!
      # end
      # 
      # def to_yaml
      # end
      
    end
  end
end