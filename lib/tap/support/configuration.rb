require 'tap/support/option'

module Tap
  module Support
    class Configuration < Option
      attr_reader :getter
      attr_reader :setter

      def initialize(name, default=nil, arg=:mandatory, getter=name, setter="#{name}=")
        super(name, default, arg)
        self.getter = getter
        self.setter = setter
      end
      
      # Sets the getter for self.  The getter is symbolized.
      def getter=(value)
        @getter = value.to_sym
      end
      
      # Sets the setter for self.  The setter is symbolized.
      def setter=(value)
        @setter = value.to_sym
      end
      
      # Updates the specified properties for self.  Allowed update properties
      # are [:name, :default, :arg, :getter, :setter].  Raises an error if
      # the property cannot be updated.  
      def update(properties={})
        properties.each_pair do |key, value|
          case key
          when :default then self.default = value
          when :arg then self.arg = value
          when :name then self.name = value
          when :getter then self.getter = value
          when :setter then self.setter = value
          else
            raise "update cannot handle property: #{key}"
          end
        end
      end
      
      # True if another is a kind of Configuration and all attributes are equal.
      def ==(another)
        another.kind_of?(Configuration) && 
        self.name == another.name &&
        self.arg == another.arg &&
        self.getter == another.getter &&
        self.setter == another.setter &&
        self.default(false) == another.default(false)
      end
    end
  end
end