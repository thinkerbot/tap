module Tap
  module Support
    
    # ConfigurableMethods encapsulates all class methods used to declare
    # configurations in Tasks.  When configurations are declared using
    # the config method, ConfigurableMethods generates accessors in the
    # class, much like attr_reader, attr_writer, and attr_accessor.  
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

      # Declares a configuration without any accessors.
      #
      # With no keys specified, sets the config_mode to make no  
      # accessors for new config declarations.
      def declare_config(*keys)
        if keys.empty?
          self.config_mode = :none 
        else 
          keys.each {|key| configurations.add(key)}
        end
      end

      # Creates a configuration writer for the input keys.  Works like
      # attr_writer, except the value is sent to the set_config method
      # rather than a local variable.  set_config must be implemented
      # independently.
      #
      # With no keys specified, sets the config_mode to make a
      # config_writer for new config declarations.
      def config_writer(*keys)
        if keys.empty?
          self.config_mode = :config_writer 
        else 
          keys.each do |key|
            configurations.add(key)
            define_config_writer(key)
          end
        end
      end

      # Creates a configuration reader for the input keys.  Works like
      # attr_reader, except the value is obtained from the get_config
      # method rather than a local variable.  get_config must be 
      # implemented independently.
      #
      # With no keys specified, sets the config_mode to make a
      # config_reader for new config declarations.
      def config_reader(*keys)
        if keys.empty?
          self.config_mode = :config_reader 
        else 
          keys.each do |key|
            configurations.add(key)
            define_config_reader(key)
          end
        end
      end

      # Creates configuration accessors for the input keys.  Works like
      # attr_accessor, except the value is read and written as in
      # config_writer and config_reader.
      #
      # With no keys specified, sets the config_mode to make a
      # config_accessor for new config declarations.
      def config_accessor(*keys)
        if keys.empty?
          self.config_mode = :config_accessor 
        else 
          keys.each do |key|
            configurations.add(key)
            define_config_reader(key)
            define_config_writer(key)
          end
        end
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
      # A block can be specified for validation/pre-processing.  If the
      # set_config/get_config methods are implemented as in Configurable
      # (as below) then all inputs set through the config accessors are
      # automatically processed by the block.  
      #
      # The Tap::Support::Validation module provides methods to perform 
      # common checks and transformations.  These can be accessed through 
      # the class method 'c':
      #
      #   class ValidatingClass
      #     include Configurable   # effectively extends self with ConfigurableMethods
      # 
      #     config(:one, 'one') {|v| v.upcase}
      #     config :two, 'two', &c.check(String)
      #   end
      #
      #   t = ValidatingClass.new
      #
      #   # Note the default values are also processed
      #   t.one                     # => 'ONE'
      #   t.one = 'One'             
      #   t.one                     # => 'ONE'
      
      #   t.two                     # => 'two'
      #   t.two = 2                 # !> ValidationError
      #   t.two                     # => 'two'
      #   
      def config(key, value=nil, &validation)
        configurations.add(key, value, &validation)

        case config_mode
        when :config_accessor
          define_config_writer(key)
          define_config_reader(key)
        when :config_writer
          define_config_writer(key)
        when :config_reader
          define_config_reader(key)
        end
      end
      
      # Merges the configurations from the specified class and 
      # makes accessors for new keys in the current config_mode 
      # (like config).  Raises an error if the configurations 
      # cannot be merged.
      def config_merge(klass)
        configurations.merge!(klass.configurations) do |key|
          case config_mode
          when :config_accessor
            define_config_writer(key)
            define_config_reader(key)
          when :config_writer
            define_config_writer(key)
          when :config_reader
            define_config_reader(key)
          end
        end
      end
      
      protected
      
      # Sets the current config_mode
      attr_writer :config_mode

      # Tracks the current configuration mode, to determine what
      # in any accessors should be generated for the configuration.
      # (default :config_accessor)
      def config_mode
        @config_mode ||= :config_accessor
      end
      
      # Alias for Tap::Support::Validation
      def c
        Validation
      end

      private
      
      # Defines an instance method by the specified name to call
      # the get_config method with key. get_config needs to be
      # implemented in the extended class.
      def define_config_reader(name, key=name) 
        define_method(name) do
          get_config(key)
        end
      end

      # Defines an instance method "#{name}=" to call the set_config 
      # method with key and the set input. set_config needs to be
      # implemented in the extended class.
      def define_config_writer(name, key=name)
        define_method("#{name}=") do |value|
          set_config(key, value)
        end
      end
    end
  end
end