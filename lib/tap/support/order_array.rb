module Tap
  module Support
    class OrderArray
      include Enumerable
      
      def initialize(parent=nil)
        existing_array = case parent
        when OrderArray then parent.array
        when Array then parent
        when nil then []
        else 
          raise ArgumentError.new("cannot convert #{parent.class} to OrderArray, Array, or nil")
        end
        
        @array = []
        existing_array.each do |key, values|
          add(key, *values)
        end
      end
      
      def keys
        array.collect {|key, values| key }
      end
      
      def values
        array.collect {|key, values| values }.flatten
      end
      
      # Returns true if the key is declared.
      def has_key?(key)
        array.each do |k, values|
          return true if k == key
        end
        false
      end
      
      # Returns true if the value has been declared for some key.
      def include?(value)
        array.each do |key, values|
          return true if values.include?(value)
        end
        false
      end
      
      # Returns the key for the specified value, or nil if no
      # key is assigned the value.
      def key_for(value)
        array.each do |key, values|
          return key if values.include?(value)
        end
        nil
      end
      
      # Returns the values for the specified key, or nil if
      # the key cannot be found.
      def values_for(key)
        array.each do |k, values| 
          return values if k == key
        end
        nil
      end
      
      # Adds the specified values for the key.  Raises an error if another key
      # already has one of the input values.
      def add(key, *values)
        array << [key, []] unless has_key?(key)
        values_for(key).concat values
      end
      
      # Removes the specified value
      def remove(value)
        array.each do |key, values| 
          break if values.delete(value)
        end
      end
      
      # Removes all values for the specified key
      def remove_key(key)
        array.delete_if {|k, values| k == key}
      end
      
      # 
      def each # :yields: key, value
        array.each do |key, values|
          values.each {|value| yield(key, value) }
        end
      end
      
      def to_a
        array.dup
      end
      
      protected
      
      # An array of [key, values] arrays tracking the key and order
      # in which values were added. 
      attr_reader :array
      
    end
  end
end