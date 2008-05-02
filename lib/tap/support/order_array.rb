module Tap
  module Support
    
    # Assignments defines an array of [key, values] pairs that tracks 
    # which values are assigned to a particular key.  A value may only 
    # be assigned to one key at a time.  
    #
    # Assignments tracks the order in which keys are declared, and the
    # order in which values are assigned to a key.  This behavior is
    # used by Tap to track the order in which configurations are 
    # assigned to a class; the order, in turn, is used in the formation
    # of config files, command line documentation, etc.
    class Assignments
      include Enumerable
      
      def initialize(parent=nil)
        existing_array = case parent
        when Assignments then parent.array
        when Array then parent
        when nil then []
        else 
          raise ArgumentError.new("cannot convert #{parent.class} to Assignments, Array, or nil")
        end
        
        @array = []
        existing_array.each do |key, values|
          assign(key, *values)
        end
      end
      
      # Adds the key to the declarations.
      def declare(key)
        array << [key, []]
      end
      
      # Removes all values for the specified key and 
      # removes the key from declarations.
      def undeclare(key)
        array.delete_if {|k, values| k == key}
      end
      
      # Returns true if the key is declared.
      def declared?(key)
        array.each do |k, values|
          return true if k == key
        end
        false
      end
      
      # Returns an array of all the declared keys
      def declarations
        array.collect {|key, values| key }
      end

      # Assigns the specified values to the key.  The key will
      # be declared, if necessary. Raises an error if the key
      # is nil. 
      def assign(key, *values)
        raise ArgumentError.new("nil keys are not allowed") if key == nil
        
        declare(key) unless declared?(key)
        
        current_values = self.values
        existing_values, new_values = values.partition {|value| current_values.include?(value) }
        
        conflicts = []
        existing_values.collect do |value|
          current_key = key_for(value)
          if current_key != key 
            conflicts << "#{value} (#{key}) already assigned to #{current_key}"
          end
        end
        
        unless conflicts.empty?
          raise ArgumentError.new(conflicts.join("\n"))
        end
        
        values_for(key).concat new_values
      end
      
      # Removes the specified value.
      def unassign(value)
        array.each do |key, values| 
          values.delete(value)
        end
      end
      
      # Returns true if the value has been assigned to a key.
      def assigned?(value)
        array.each do |key, values|
          return true if values.include?(value)
        end
        false
      end

      # Returns the ordered values as an array
      def values
        array.collect {|key, values| values}.flatten
      end
  
      # Returns the key for the specified value, or nil 
      # if the value is unassigned.
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

      # Yields each key, value pair in the order in which
      # the keys were declared.
      def each # :yields: key, value
        array.each do |key, values|
          values.each {|value| yield(key, value) }
        end
      end
      
      # Returns the ordered values as an array (alias for values)
      def to_a
        array.collect {|key, values| [key, values.dup] }
      end
      
      protected
      
      # An array of [key, values] arrays tracking the key and order
      # in which values were assigned. 
      attr_reader :array
      
    end
  end
end