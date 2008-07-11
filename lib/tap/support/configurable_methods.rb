require 'tap/support/class_configuration'
require 'tap/support/validation'
require 'tap/support/cdoc'

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
    # If a block is given, the block will be used to create the writer method
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
    # config_attr method which defines the writer method using the block directly.
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
      
      protected
      
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
      def config(key, value=nil, options={}, &block)
        if block_given?
          # add arg_type implied by block, if necessary
          options[:arg_type] = arg_type(block) if options[:arg_type] == nil
          options[:arg_name] = arg_name(block) if options[:arg_name] == nil
          
          instance_variable = "@#{key}".to_sym
          config_attr(key, value, options) do |input|
            instance_variable_set(instance_variable, block.call(input))
          end
        else
          config_attr(key, value, options)
        end
      end
      
      # Declares a class configuration and generates the associated accessors. 
      # If a block is given, the :key= method will perform the block.  
      # Configurations are inherited, and can be overridden in subclasses. 
      #
      #   class SampleClass
      #     include Tap::Support::Configurable
      #
      #     def initialize
      #       initialize_config
      #     end
      #
      #     config_attr :str, 'value'
      #     config_attr(:upcase, 'value') {|input| @upcase = input.upcase } 
      #   end
      #
      #   # Regarding accesssors (and accessors only), 
      #   # this is the same class
      #   class EquivalentClass
      #     attr_accessor :str
      #     attr_reader :upcase
      #
      #     def upcase=(input)
      #       @upcase = input.upcase
      #     end
      #   end
      #
      # Once declared, configurations may be set through config.  The config
      # object is an InstanceConfiguration which forward get/set operations
      # to the configuration reader and writer.  For example:
      #
      #   s = SampleClass.new
      #   s.config.class            # => Tap::Support::InstanceConfiguration
      #   s.str                     # => 'value'
      #   s.config[:str]            # => 'value'
      #
      #   s.str = 'one'
      #   s.config[:str]            # => 'one'
      #   
      #   s.config[:str] = 'two' 
      #   s.str                     # => 'two'
      # 
      # Alternative reader and writer methods may be specified as an option,
      # in which case config_attr assumes the methods are declared elsewhere
      # and will not define the associated accessors.  
      # 
      #   class AlternativeClass
      #     include Tap::Support::Configurable
      #
      #     config_attr :sym, 'value', :reader => :get_sym, :writer => :set_sym
      #
      #     def initialize
      #       initialize_config
      #     end
      #
      #     def get_sym
      #       @sym
      #     end
      #
      #     def set_sym(input)
      #       @sym = input.to_sym
      #     end
      #   end
      #
      #   alt = AlternativeClass.new
      #   alt.respond_to?(:sym)     # => false
      #   alt.respond_to?(:sym=)    # => false
      #   
      #   alt.config[:sym] = 'one'
      #   alt.get_sym               # => :one
      #
      #   alt.set_sym('two')
      #   alt.config[:sym]          # => :two
      #
      # Idiosyncratically, true, false, and nil may also be provided as 
      # reader/writer options. Specifying true is the same as using the 
      # default.  Specifying false or nil prevents config_attr from 
      # defining accessors, but the configuration still expects to use 
      # the default reader/writer methods (ie key and key=) which must
      # be defined elsewhere.
      #
      # See Tap::Support::Configurable for more details.
      def config_attr(key, value=nil, options={}, &block)
        
        # add arg_type implied by block, if necessary
        options[:arg_type] = arg_type(block) if block_given? && options[:arg_type] == nil
        options[:arg_name] = arg_name(block) if block_given? && options[:arg_name] == nil

        # define the default public reader method
        if !options.has_key?(:reader) || options[:reader] == true
          attr_reader(key) 
          public key
        end
        
        # define the public writer method
        case
        when options.has_key?(:writer) && options[:writer] != true
          raise ArgumentError.new("block may not be specified with writer") if block_given?
        when block_given? 
          define_method("#{key}=", &block)
          public "#{key}="
        else
          attr_writer(key)
          public "#{key}="
        end

        # remove any true, false, nil reader/writer declarations...
        # implicitly reverting the option to the default reader
        # and writer methods
        [:reader, :writer].each do |option|
          case options[option]
          when true, false, nil then options.delete(option)
          end
        end

        # register with CDoc so that all extra documentation can be extracted
        caller.each_with_index do |line, index|
          case line
          when /in .config.$/ then next
          when /^(([A-z]:)?[^:]+):(\d+)/
            comment = CDoc.instance.register($1, $3.to_i - 1)
            options[:desc] = comment if options[:desc] == nil
            options[:summary] = comment if options[:summary] == nil
            break
          end
        end
        
        configurations.add(key, value, options)
      end

      # Alias for Tap::Support::Validation
      def c
        Validation
      end
      
      private
      
      # Returns special argument types for standard validation
      # blocks, such as switch (Validation::SWITCH) and list
      # (Validation::LIST).
      def arg_type(block) # :nodoc:
        case block
        when Validation::SWITCH then :switch
        when Validation::LIST then :list
        else nil
        end
      end
      
      # Returns special argument names for standard validation
      # blocks, such as switch (Validation::ARRAY) and list
      # (Validation::HASH).
      def arg_name(block) # :nodoc:
        case block
        when Validation::ARRAY then "'[a, b, c]'"
        when Validation::HASH then "'{one: 1, two: 2}'"
        else nil
        end
      end
    end
  end
end