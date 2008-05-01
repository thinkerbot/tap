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
    module Configurable
      
      def self.included(mod)
        mod.extend Support::ConfigurableMethods if mod.kind_of?(Class)
      end
      
      # A configuration hash.
      attr_reader :config
    
      # Sets config with the given configuration overrides, merged with the class
      # default configuration.  Configurations are symbolized before they are merged,
      # and validated as specified in the config declarations.
      def config=(overrides)
        @config = self.class.configurations.default.dup
        overrides.each_pair {|key, value| set_config(key.to_sym, value) } 
        self.config
      end
      
      protected

      # Sets the specified configuration, processing the input value using
      # the block specified in the config declaration.  The input key should
      # be symbolized.
      def set_config(key, value)
        config[key] = self.class.configurations.process(key, value)
      end
    end
  end
end