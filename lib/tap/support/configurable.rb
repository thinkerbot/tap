require 'tap/support/configurable_methods'

module Tap
  module Support
    
    # Configurable facilitates the definition and use of configurations by objects.  
    # Configurable allows the specification of configs within the class definition.
    #
    #   class ConfigurableClass
    #     include Configurable
    # 
    #     config :one, 'one'
    #     config :two, 'two'
    #     config :three, 'three'
    #
    #     def initialize(overrides={})
    #       self.config = overrides
    #     end
    #   end
    #
    #   c = ConfigurableClass.new
    #   c.config.class         # => InstanceConfiguration
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
      
      # The instance configurations for self
      attr_reader :config
      
      # Sets config for self with the given configuration overrides.
      def config=(overrides)
        @config = self.class.configurations.instance_config
        overrides.each_pair do |key, value|
          config[key.to_sym] = value
        end
        config.bind(self)
      end
      
    end
  end
end