module Tap
  module Support
    
    # Configurable encapsulates all configuration-related methods used
    # by Tasks.  When Configurable is included in a class, the class itself
    # is extended with Tap::Support::ConfigurableMethods, such that configs
    # can be declared within the class definition.
    #
    #   class ConfigurableClass
    #     include Configurable
    # 
    #     config :one, 'one'
    #     config :two, 'two'
    #     config :three, 'three'
    #   end
    #
    #   ConfigurableClass.new.config  # => {:one => 'one', :two => 'two', :three => 'three'}
    #
    #--
    # See the 'Configuration' section in the Tap::Task documentation for
    # more details on how Configurable works in practice.
    #--
    # === Example
    # In general ClassConfigurations are only interacted with through ConfigurableMethods.
    # These define attr-like readers/writers/accessors:
    #  
    #   class BaseClass
    #     include Tap::Support::Configurable
    #     config :one, 1
    #     config :three, 3
    #   end
    #
    #   BaseClass.configurations.default    # => {:one => 1, :three => 3}
    #
    # ClassConfigurations are inherited and decoupled from the parent.  You
    # may need to interact with configurations directly:
    #
    #   class SubClass < BaseClass
    #     config :one, 'one'
    #     config :two, 'TWO' {|value| value.downcase }
    #
    #     configurations.remove(:three)
    #   end
    #
    #   BaseClass.configurations.default              # => {:one => 1, :three => 3}
    #   SubClass.configurations.default               # => {:one => 'one', :two => 'two'}
    #   SubClass.configurations.unprocessed_default   # => {:one => 'one', :two => 'TWO'}
    #
    module Configurable
      
      # Extends including classes with Support::ConfigurableMethods
      def self.included(mod)
        mod.extend Support::ConfigurableMethods if mod.kind_of?(Class)
      end
      
      # A configuration hash
      attr_reader :config
      
      def initialize(overrides={})
        self.config = overrides
      end
      
      # Returns a reference to the class configurations for self
      def class_configurations
        @class_configurations ||= self.class.configurations
      end
      
      # Sets config with the given configuration overrides, merged with the class
      # default configuration.  Configurations are symbolized before they are merged,
      # and validated as specified in the config declarations.
      def config=(overrides)
        @config = class_configurations.default.dup
        overrides.each_pair {|key, value| set_config(key, value) } 
        self.config
      end
      
      protected
      
      # Sets the specified configuration, processing the input value using
      # the block specified in the config declaration.  The input key should
      # be symbolized.
      def set_config(key, value)
        config[class_configurations.normalize_key(key)] = class_configurations.process(key, value)
      end
      
      # Gets the specified configuration.
      def get_config(key)
        config[class_configurations.normalize_key(key)]
      end
    end
  end
end