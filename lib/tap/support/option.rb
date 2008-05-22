module Tap
  module Support
    class Option
      attr_accessor :name
      attr_accessor :arg
      attr_reader :duplicable
      
      def initialize(name, default=nil, arg=:mandatory)
        @name = name
        @arg = arg
        self.default = default
      end
      
      # Sets the default value for self and determines if the
      # default is duplicable (ie not nil, true, false, Symbol, 
      # Numeric, and responds_to?(:dup)).
      def default=(value)
        @duplicable = case value
        when nil, true, false, Symbol, Numeric then false
        else value.respond_to?(:dup)
        end
        
        @default = value.freeze
      end
      
      # Returns the default value, or a duplicate of the default
      # value if specified and the default value is duplicable.
      def default(duplicate=true)
        duplicate && duplicable ? @default.dup : @default
      end
      
      # True if another is a kind of Option and all attributes are equal.
      def ==(another)
        another.kind_of?(Option) && 
        self.name == another.name &&
        self.arg == another.arg &&
        self.default(false) == another.default(false)
      end
    end
  end
end