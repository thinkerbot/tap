require 'tap/support/option'

module Tap
  module Support
    class Configuration < Option
      attr_reader :getter
      attr_reader :setter

      def initialize(name, default=nil, properties={}, getter=name, setter="#{name}=")
        super(name, default, properties)
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
      
      # True if another is a kind of Configuration and all attributes are equal.
      def ==(another)
        super &&
        another.kind_of?(Configuration) && 
        self.getter == another.getter &&
        self.setter == another.setter
      end
    end
  end
end