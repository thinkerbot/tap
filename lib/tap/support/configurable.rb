require 'tap/support/configurable_methods'

module Tap
  module Support
    
    # Configurable facilitates the definition and use of configurations by objects.  
    # Configurable allows the specification of configs within the class definition.
    #
    # == Usage
    #
    # Configurable must be included in the class definition and the including class
    # must initialize the @config variable, which is usually most conveniently done
    # through the config= method.
    #
    #   class ConfigurableClass
    #     include Configurable
    # 
    #     config :one, 'one'
    #     config :two, 'two'
    #     config :three, 'three'
    #
    #     def initialize(overrides={})
    #       # initializing configs in this way sets configs
    #       # to the class defaults, which are overrided as
    #       # specified
    #       self.config = overrides
    #     end
    #   end
    #
    #   c = ConfigurableClass.new
    #   c.config               # => {:one => 'one', :two => 'two', :three => 'three'}
    #
    # Configurable extends the including class with Tap::Support::ConfigurableMethods.  As
    # such, configurations are given accessors that read and write to config:
    #
    #   c.config[:one] = 'ONE'
    #   c.one                  # => 'ONE'
    #
    #   c.one = 1           
    #   c.config               # => {:one => 1, :two => 'two', :three => 'three'}
    #
    # A validation/transform block can be provided to modify configurations as
    # they are set. The Tap::Support::Validation module provides a number of 
    # common validation and transform blocks, which can be accessed through the   
    # class method 'c':
    #
    #   class ValidatingClass < ConfigurableClass
    #     config(:one, 'one') {|v| v.upcase }
    #     config :two, 'two', &c.check(String)
    #   end
    #
    #   v = ValidatingClass.new
    #   v.config              # => {:one => 'ONE', :two => 'two', :three => 'three'}
    #   v.one = 'aNothER'             
    #   v.one                 # => 'ANOTHER'
    #   v.two = 2             # !> ValidationError
    #
    # As can be seen, configurations are inherited from the parent and can be
    # overridden in subclasses.
    #
    module Configurable
      
      # Extends including classes with Support::ConfigurableMethods
      def self.included(mod)
        mod.extend Support::ConfigurableMethods if mod.kind_of?(Class)
      end
      
      # Returns a reference to the class configurations for self
      def class_configurations
        @class_configurations ||= self.class.configurations
      end
      
      # Sets config for self with the given configuration overrides.
      # Overrides are merged with the class default configuration.  
      # Overrides are individually set through set_config.
      def config=(overrides)
        @undeclared_config = overrides.symbolize_keys
        class_configurations.each_default_pair do |key, value|
          send("#{key}=", @undeclared_config.has_key?(key) ? @undeclared_config.delete(key) : value)
        end
      end
      
      def config(all=true)
        if all
          hash = config(false).dup
          class_configurations.default.each_pair do |key, value|
            hash[key] = send(key)
          end
          hash
        else
          @undeclared_config ||= {}
        end
      end
      
    end
  end
end