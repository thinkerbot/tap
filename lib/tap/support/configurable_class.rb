require 'tap/support/class_configuration'
require 'tap/support/validation'
require 'tap/support/lazy_attributes'

module Tap
  module Support
    autoload(:Templater, 'tap/support/templater')
    
    # ConfigurableClass encapsulates class methods used to declare class configurations. 
    # When configurations are declared using the config method, ConfigurableClass 
    # generates accessors in the class, much like attr_accessor.  
    #
    #   class ConfigurableClass
    #     extend ConfigurableClass
    #     config :one, 'one'
    #   end
    #
    #   ConfigurableClass.configurations.to_hash   # => {:one => 'one'}
    #
    #   c = ConfigurableClass.new
    #   c.respond_to?('one')                       # => true
    #   c.respond_to?('one=')                      # => true
    # 
    # If a block is given, the block will be used to create the writer method
    # for the config.  Used in this manner, config defines a <tt>config_key=</tt> method 
    # wherein <tt>@config_key</tt> will be set to the return value of the block.
    #
    #   class AnotherConfigurableClass
    #     extend ConfigurableClass
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
    #     extend ConfigurableClass
    #     config_attr(:one, 'one') {|value| @one = value.reverse }
    #   end
    #
    #   ac = YetAnotherConfigurableClass.new
    #   ac.one = 'value'
    #   ac.one               # => 'eulav'
    #
    module ConfigurableClass
      include Tap::Support::LazyAttributes
      
      # A ClassConfiguration holding the class configurations.
      attr_reader :configurations

      # Sets the source_file for base and initializes base.configurations.
      def self.extended(base)
        caller.each_with_index do |line, index|
          case line
          when /\/configurable.rb/ then next
          when /^(([A-z]:)?[^:]+):(\d+)/
            base.instance_variable_set(:@source_file, File.expand_path($1))
            break
          end
        end
        
        base.instance_variable_set(:@configurations, ClassConfiguration.new(base))
      end

      # When subclassed, the parent.configurations are duplicated and passed to 
      # the child class where they can be extended/modified without affecting
      # the configurations of the parent class.
      def inherited(child)
        unless child.instance_variable_defined?(:@source_file)
          caller.first =~ /^(([A-z]:)?[^:]+):(\d+)/
          child.instance_variable_set(:@source_file, File.expand_path($1)) 
        end
        
        child.instance_variable_set(:@configurations, ClassConfiguration.new(child, @configurations))
        super
      end
      
      def lazydoc(resolve=true)
        Lazydoc.resolve_comments(configurations.code_comments) if resolve
        super
      end
      
      # Loads the contents of path as YAML.  Returns an empty hash if the path 
      # is empty, does not exist, or is not a file.
      def load_config(path)
        return {} if path == nil || !File.file?(path)

        YAML.load_file(path) || {}
      end
      
      protected
      
      # Declares a class configuration and generates the associated accessors. 
      # If a block is given, the <tt>key=</tt> method will set <tt>@key</tt> 
      # to the return of the block, which executes in class-context.  
      # Configurations are inherited, and can be overridden in subclasses. 
      #
      #   class SampleClass
      #     include Tap::Support::Configurable
      #
      #     config :str, 'value'
      #     config(:upcase, 'value') {|input| input.upcase } 
      #   end
      #
      #   # An equivalent class to illustrate class-context
      #   class EquivalentClass
      #     attr_accessor :str
      #     attr_reader :upcase
      #
      #     UPCASE_BLOCK = lambda {|input| input.upcase }
      #
      #     def upcase=(input)
      #       @upcase = UPCASE_BLOCK.call(input)
      #     end
      #   end
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
      # If a block is given, the <tt>key=</tt> method will perform the block with
      # instance-context.  Configurations are inherited, and can be overridden 
      # in subclasses. 
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
      #   # An equivalent class to illustrate instance-context
      #   class EquivalentClass
      #     attr_accessor :str
      #     attr_reader :upcase
      #
      #     def upcase=(input)
      #       @upcase = input.upcase
      #     end
      #   end
      #
      # Instances of a Configurable class may set configurations through config.
      # The config object is an InstanceConfiguration which forwards read/write 
      # operations to the configuration accessors.  For example:
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
      # Alternative reader and writer methods may be specified as an option;
      # in this case config_attr assumes the methods are declared elsewhere
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
      # defining accessors; false sets the configuration to use 
      # the default reader/writer methods (ie <tt>key</tt> and <tt>key=</tt>,
      # which must be defined elsewhere) while nil prevents read/write
      # mapping of the config to a method.
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

        # remove any true, false reader/writer declarations...
        # implicitly reverting the option to the default reader
        # and writer methods
        [:reader, :writer].each do |option|
          case options[option]
          when true, false then options.delete(option)
          end
        end
        
        # register with TDoc so that all extra documentation can be extracted
        caller.each_with_index do |line, index|
          case line
          when /in .config.$/ then next
          when /^(([A-z]:)?[^:]+):(\d+)/
            options[:desc] = Lazydoc.register($1, $3.to_i - 1)
            break
          end
        end if options[:desc] == nil
        
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
        when Validation::FLAG then :flag
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