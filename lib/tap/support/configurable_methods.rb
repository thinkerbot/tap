require 'tap/support/class_configuration'

module Tap
  module Support
    
    # ConfigurableMethods encapsulates class methods used to declare class
    # configurations. When configurations are declared using the config method, 
    # ConfigurableMethods generates accessors in the class, much like attr_reader, 
    # attr_writer, and attr_accessor.  
    #
    #   class ConfigurableClass
    #     extend ConfigurableMethods
    # 
    #     config :one, 'one'
    #     config :two, 'two'
    #     config :three, 'three'
    #   end
    #
    #   ConfigurableClass.configurations.default  # => {:one => 'one', :two => 'two', :three => 'three'}
    #   c = ConfigurableClass.new
    #   c.respond_to?('one')                       # => true
    #   c.respond_to?('one=')                      # => true
    # 
    # By default config defines a config_accessor for each configuration, but
    # this can be modulated using declare_config, config_reader, config_writer, 
    # and config_accessor.  These methods define accessors that call 
    # get_config(key) and set_config(key, value), both of which must be 
    # implemented in the extended class.  Although they can be called directly,
    # they are more commonly used to flag what types of accessors config should
    # create:
    # 
    #   class AnotherConfigurableClass
    #     extend ConfigurableMethods
    #
    #     config_writer           # flags config to define writers-only
    #     config :one, 'one'
    #
    #     config_reader           # flags config to define readers-only
    #     config :two, 'two'
    #   end
    #
    #   c = AnotherConfigurableClass.new
    #   c.respond_to?('one')                       # => false
    #   c.respond_to?('one=')                      # => true
    #   c.respond_to?('two')                       # => true
    #   c.respond_to?('two=')                      # => false
    #
    # ConfigurableMethods can extend any class to provide class-specific configurations.
    module ConfigurableMethods
      
      # A Tap::Support::ClassConfiguration holding the class configurations.
      attr_reader :configurations
      
      # ConfigurableMethods initializes base.configurations on extend.
      def self.extended(base)
        base.instance_variable_set(:@configurations, ClassConfiguration.new(base))
      end
      
      # When subclassed, the parent.configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        child.instance_variable_set(:@configurations, ClassConfiguration.new(child, @configurations))
      end

      # Sets a class configuration.  Configurations are inherited, but can 
      # be overridden or added in subclasses. Accessors are created by 
      # default, but this behavior can be modified by use of the other
      # config methods.  
      #
      #   class SampleClass
      #     extend ConfigurableMethods
      #
      #     config :key, 'value'
      #
      #     config_reader
      #     config :reader_only
      #   end
      #
      #   t = SampleClass.new
      #   t.respond_to?(:reader_only)         # => true
      #   t.respond_to?(:reader_only=)        # => false
      #
      # A block can be specified for validation/pre-processing.  See
      # Tap::Support::Configurable for more details.
      #
      #--
      # class context
      def config(key, value=nil)
        if block_given?
          instance_variable = "@#{key}".to_sym
          config_attr(key, value) do |value|
            instance_variable_set(instance_variable, yield(value))
          end
        else
          config_attr(key, value)
        end
      end
      
      #--
      # instance context
      def config_attr(key, value=nil, &block)
        configurations.add(key, value)
        
        attr_reader(key)
        if block_given? 
          define_method("#{key}=", &block)
        else attr_writer(key)
        end
      end
      
      protected
      
      # Alias for Tap::Support::Validation
      def c
        Validation
      end
    end
  end
end