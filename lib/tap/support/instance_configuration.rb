module Tap
  module Support
    class InstanceConfiguration
      
      attr_reader :receiver, :store
      
      def initialize
        @store = {}
        @map = {}
      end
      
      # Maps the key to the receiver accessors :key and :key=
      # and stores the default value for the key.  An alternate
      # setter can be specified using setter.  Raises an error
      # if bound? is true.
      #
      # Note: the default value is recorded in store.  Until
      # bound, the default value can be modified through []=
      def map(key, default_value=nil, setter="#{key}=")
        raise "cannot map keys when bound" if bound?

        key = key.to_sym
        @map[key] = setter.to_sym
        store[key] = default_value
      end
      
      # Unmaps the key from the receiver accessors and deletes
      # the stored default value. Raises an error if bound? is 
      # true.
      def unmap(key)
        raise "cannot unmap keys when bound" if bound?
        
        @map.delete(key.to_sym)
        store.delete(key.to_sym)
      end
      
      # True if the key is mapped.
      def mapped?(key)
        @map.has_key?(key)
      end
      
      # An array of the mapped keys.
      def mapped_keys
        @map.keys
      end
      
      # Returns the mapped setter method for the specified key.
      # Raises an error if the key is not mapped.
      def map_setter(key)
        @map[key] or raise(ArgumentError.new("not a mapped key"))
      end
      
      # Returns the default map value.  If duplicate is true, then 
      # all duplicable values will be duplicated (so that modifications
      # to them will not affect the original default value).  Raises
      # an error if the key is not mapped.
      def map_default(key, duplicate=true)
        raise ArgumentError.new("not a mapped key") unless mapped?(key)
        
        default = store[key]
        if duplicate
          case default
          when nil, true, false, Symbol, Numeric then default
          else default.dup
          end
        else default
        end
      end
      
      # Binds config to the specified receiver.  If set_default_values == true
      # then all mapped keys will be set with their map_default values.
      def bind(receiver, set_default_values=true)
        mapped_keys.each do |key|
          receiver.send(map_setter(key), map_default(key))
        end if set_default_values
        @receiver = receiver
      end
      
      # Returns true if self is bound to a receiver
      def bound?
        receiver != nil
      end
      
      # Duplicates self, returning an unbound InstanceConfiguration.
      def dup(receiver=nil, overrides={}, symbolize=true)
        duplicate = super()
        duplicate.instance_variable_set(:@receiver, receiver)
        duplicate.instance_variable_set(:@store, @store.dup)
        duplicate.instance_variable_set(:@map, @map.dup)
        
        keys = mapped_keys
        overrides.each_pair do |key, value|
          key = key.to_sym if symbolize
          duplicate[key] = value
          keys.delete(key)
        end
        keys.each do |key|
          duplicate[key] = map_default(key)
        end 
        
        duplicate
      end
      
      def []=(key, value)
        case 
        when bound? && mapped?(key)
          receiver.send(map_setter(key), value)
        else store[key] = value
        end
      end
      
      def [](key)
        case 
        when bound? && mapped?(key)
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
          next if mapped?(key)
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
        hash = {}
        store.keys.each do |key|
          hash[key] = self[key]
        end
        hash
      end
      

      # 
      # # Returns true if the key is mapped to the receiver.
      # def mapped?(key)
      #   getters.include?(key) 
      # end
      # 
      # # Returns mapped and stored keys.
      # def keys
      #   getters + store.keys
      # end
      # 
      # # Returns mapped and stored values.
      # def values
      #   keys.collect {|key| self[key] }
      # end
      # 
      # # Returns true if keys includes key.
      # def has_key?(key)
      #   getters.include?(key) || store.has_key?(key)
      # end
      # 
      # def clear
      # end
      # 

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