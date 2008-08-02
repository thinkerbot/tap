require 'tap/support/configurable_class'

module Tap
  module Support
    
    # Configurable enables the specification of configurations within a class definition.
    #
    #   class ConfigClass
    #     include Configurable
    # 
    #     config :one, 'one'
    #     config :two, 'two'
    #     config :three, 'three'
    #
    #     def initialize(overrides={})
    #       initialize_config(overrides)
    #     end
    #   end
    #
    #   c = ConfigClass.new
    #   c.config.class         # => InstanceConfiguration
    #   c.config               # => {:one => 'one', :two => 'two', :three => 'three'}
    #
    # The <tt>config</tt> object acts as a kind of forwarding hash; declared configurations
    # map to accessors while undeclared configurations are stored internally:
    #
    #   c.config[:one] = 'ONE'
    #   c.one                  # => 'ONE'
    #
    #   c.one = 1           
    #   c.config               # => {:one => 1, :two => 'two', :three => 'three'}
    #
    #   c.config[:undeclared] = 'value'
    #   c.config.store         # => {:undeclared => 'value'}
    #
    # The writer method for a configuration can be modified by providing a block to config.  
    # The Validation module provides a number of common validation and string-transform 
    # blocks which can be accessed through the class method 'c':
    #
    #   class SubClass < ConfigClass
    #     config(:one, 'one') {|v| v.upcase }
    #     config :two, 2, &c.integer
    #   end
    #
    #   s = SubClass.new
    #   s.config               # => {:one => 'ONE', :two => 2, :three => 'three'}
    #
    #   s.one = 'aNothER'             
    #   s.one                  # => 'ANOTHER'
    #
    #   s.two = -2
    #   s.two                  # => -2
    #   s.two = "3"
    #   s.two                  # => 3
    #   s.two = nil            # !> ValidationError
    #   s.two = 'str'          # !> ValidationError
    #
    # As shown above, configurations are inherited from the parent and can be
    # overridden in subclasses.  See ConfigurableClass for more details.
    #
    module Configurable
      
      # Extends including classes with ConfigurableClass
      def self.included(mod)
        mod.extend Support::ConfigurableClass if mod.kind_of?(Class)
      end
      
      # The instance configurations for self
      attr_reader :config
      
      # Reconfigures self with the given configuration overrides.  Only
      # the specified configs are modified.  Override keys are symbolized.
      #
      # Returns self.
      def reconfigure(overrides={})
        keys = (config.class_config.ordered_keys + overrides.keys) & overrides.keys
        keys.each do |key|
          config[key.to_sym] = overrides[key] 
        end

        self
      end
      
      # Reinitializes config with a copy of orig.config (this assures
      # that duplicates have their own copy of configurations, 
      # separate from the original object).
      def initialize_copy(orig)
        super
        initialize_config(orig.config)
      end
      
      protected
      
      # Initializes config to an InstanceConfiguration specific for self.
      # Default config values are assigned or overridden if specified in
      # overrides. Override keys are symbolized.
      def initialize_config(overrides={})
        class_config = self.class.configurations
        @config = class_config.instance_config
        
        overrides.each_pair do |key, value|
          config[key.to_sym] = value
        end
        
        class_config.each_pair do |key, value|
          next if config.has_key?(key)
          config[key] = value.default
        end

        config.bind(self)
      end
    end
  end
end