module Tap
  module Support
    
    # ConfigurableMethods encapsulates all class methods used to declare
    # configurations in Tasks.  ConfigurableMethods extends classes that
    # include Tap::Support::Configurable.
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
    # See the 'Configuration' section in the Tap::Task documentation for
    # more details on how Configurable works in practice.
    module ConfigurableMethods
      
      # A Tap::Support::ClassConfiguration holding the class configurations.
      attr_reader :configurations
      
      # When subclassed, the configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        super
        child.instance_variable_set(:@configurations, ClassConfiguration.new(child, @configurations))
        child.instance_variable_set(:@source_files, source_files.dup)
      end
      
      # EXPERIMENTAL
      attr_reader :source_files # :nodoc:
      
      # EXPERIMENTAL
      # Identifies source files for TDoc documentation.
      def source_file(arg) # :nodoc:
        source_files << arg
      end

      # Declares a configuration without any accessors.
      #
      # With no keys specified, sets config to make no  
      # accessors for each new configuration.
      def declare_config(*keys)
        if keys.empty?
          self.config_mode = :none 
        else 
          keys.each {|key| configurations.add(key)}
        end
      end

      # Creates a configuration writer for the input keys.  Works like
      # attr_writer, except the value is written to config, rather than
      # a local variable.  In addition, the config will be validated
      # using validate_config upon setting the value.
      #
      # With no keys specified, sets config to create config_writer 
      # for each new configuration.
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
      # attr_reader, except the value is read from config, rather than
      # a local variable.
      #
      # With no keys specified, sets config to create a config_reader 
      # for each new configuration.
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
      # attr_accessor, except the value is read from and written to config, 
      # rather than a local variable.
      #
      # With no keys specified, sets config to create a config_accessor 
      # for each new configuration.
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
      #     include Configurable
      #
      #     config :key, 'value'
      #     config_reader
      #     config :reader_only
      #   end
      #
      #   t = SampleClass.new
      #   t.respond_to?(:reader_only)         # => true
      #   t.respond_to?(:reader_only=)        # => false
      #
      #   t.config               # => {:key => 'value', :reader_only => nil} 
      #   t.key                  # => 'value'
      #   t.key = 'another'
      #   t.config               # => {:key => 'another', :reader_only => nil}
      #
      # A block can be specified for validation/pre-processing.  All inputs
      # set through the config accessors, as well as the instance config= 
      # method are processed by the block before they set the value in the
      # config hash.  The config value will be set to the return of the block.
      #
      # The Tap::Support::Validation module provides methods to perform 
      # common checks and transformations.  These can be accessed through 
      # the class method 'c':
      #
      #   class ValidatingClass
      #     include Configurable
      # 
      #     config :one, 'one', &c.check(String)
      #     config :two, 'two' do |v| 
      #       v.upcase
      #     end
      #   end
      #
      #   t = ValidatingClass.new
      #   
      #   # note the default values ARE processed
      #   t.config                  # => {:one => 'one', :two => 'TWO'}
      #   t.one = 1                 # => ValidationError
      #   t.config = {:one => 1}    # => ValidationError
      #
      #   t.config = {:one => 'str', :two => 'str'}
      #   t.config                  # => {:one => 'str', :two => 'STR'}
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
      
      def config_merge(klass)
        configurations.merge(klass.configurations) do |key|
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
      
      # Returns the default name for the class: class.to_s.underscore
      def default_name
        @default_name ||= to_s.underscore
      end
      
      protected

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

      def define_config_reader(name, key=name) # :nodoc:
        key = key.to_sym
        define_method(name) do
          config[key]
        end
      end

      def define_config_writer(name, key=name) # :nodoc:
        key = key.to_sym
        define_method("#{name}=") do |value|
          set_config(key, value)
        end
      end
    end
  end
end