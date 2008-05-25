require 'tap/support/class_configuration'

module Tap
  module Support
    
    # ConfigurableMethods encapsulates class methods used to declare class configurations. 
    # When configurations are declared using the config method, ConfigurableMethods 
    # generates accessors in the class, much like attr_accessor.  
    #
    #   class ConfigurableClass
    #     extend ConfigurableMethods
    #     config :one, 'one'
    #   end
    #
    #   ConfigurableClass.configurations.default   # => {:one => 'one'}
    #   c = ConfigurableClass.new
    #   c.respond_to?('one')                       # => true
    #   c.respond_to?('one=')                      # => true
    # 
    # If a block is given, the block will be used to create the setter method
    # for the config.  Used in this manner, config defines a :config_key= method 
    # wherein @config_key will be set to the return value of the block.
    #
    #   class AnotherConfigurableClass
    #     extend ConfigurableMethods
    #     config(:one, 'one') {|value| value.upcase }
    #   end
    #
    #   ac = AnotherConfigurableClass.new
    #   ac.one = 'value'
    #   ac.one               # => 'VALUE'
    #
    # The block has class-context in this case.  To have instance-context, use the
    # config_attr method which defines the setter method using the block directly.
    #
    #   class YetAnotherConfigurableClass
    #     extend ConfigurableMethods
    #     config_attr(:one, 'one') {|value| @one = value.reverse }
    #   end
    #
    #   ac = YetAnotherConfigurableClass.new
    #   ac.one = 'value'
    #   ac.one               # => 'eulav'
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

      # Declares a class configuration and generates the associated accessors. 
      # If a block is given, the :key= method will set @key to the return of
      # the block.  Configurations are inherited, and can be overridden in 
      # subclasses. 
      #
      #   class SampleClass
      #     extend ConfigurableMethods
      #
      #     config :str, 'value'
      #     config(:upcase, 'value') {|input| input.upcase } 
      #   end
      #
      #   class EquivalentClass
      #     attr_accessor :str
      #     attr_reader :upcase
      #     UPCASE_BLOCK = lambda {|input| input.upcase }
      #
      #     def upcase=(input)
      #       @upcase = UPCASE_BLOCK.call(input)
      #     end
      #   end
      #
      # Regarding accessors, SampleClass is equivalent to EquivalentClass.  
      # The default values recorded by SampleClass are used in configuring
      # instances of SampleClass, see Tap::Support::Configurable for more
      # details.
      # 
      def config(key, value=nil, &block)
        if block_given?
          instance_variable = "@#{key}".to_sym
          config_attr(key, value) do |input|
            instance_variable_set(instance_variable, block.call(input))
          end
        else
          config_attr(key, value)
        end
      end
      
      # Declares a class configuration and generates the associated accessors. 
      # If a block is given, the :key= method will perform the block.  
      # Configurations are inherited, and can be overridden in subclasses. 
      #
      #   class SampleClass
      #     extend ConfigurableMethods
      #
      #     config_attr :str, 'value'
      #     config_attr(:upcase, 'value') {|input| @upcase = input.upcase } 
      #   end
      #
      #   class EquivalentClass
      #     attr_accessor :str
      #     attr_reader :upcase
      #
      #     def upcase=(input)
      #       @upcase = input.upcase
      #     end
      #   end
      #
      # Regarding accessors, SampleClass is equivalent to EquivalentClass.  
      # The default values recorded by SampleClass are used in configuring
      # instances of SampleClass, see Tap::Support::Configurable for more
      # details.
      #
      def config_attr(key, value=nil, reader=true, writer=true, &block)
        config = (configurations[key] || configurations.add(key))
        config.default = value
        
        # register with TDoc, not config, so that all bits can be
        # extracted at once
        caller.each do |line|
          if line =~ /^([^:]+):(\d+)$/
            config.line = $2.to_i
            config.path = File.expand_path($1)
            break
          end
        end

        attr_reader(key) if reader
        case
        when block_given? 
          define_method("#{key}=", &block)
        when writer
          attr_writer(key)
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