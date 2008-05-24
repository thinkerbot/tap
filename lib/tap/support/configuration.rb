module Tap
  module Support
    class Configuration
      
      class << self
        SHORT_REGEXP = /^-[A-z]$/
        
        # Turns the input string into a short-format option.  Raises
        # an error if the option does not match SHORT_REGEXP.
        #
        #   Configuration.shortify("-o")   # => '-o'
        #   Configuration.shortify(:o)     # => '-o'
        #
        def shortify(str)
          str = str.to_s
          str = "-#{str}" unless str[0] == ?-
          raise "invalid short option: #{str}" unless str =~ SHORT_REGEXP
          str
        end

        LONG_REGEXP = /^--(\[no-\])?([A-z][\w-]*)$/
        
        # Turns the input string into a long-format option.  Raises
        # an error if the option does not match LONG_REGEXP.
        #
        #   Configuration.longify("--opt")                     # => '--opt'
        #   Configuration.longify(:opt)                        # => '--opt'
        #   Configuration.longify(:opt, true)                  # => '--[no-]opt'
        #   Configuration.longify(:opt_ion)                    # => '--opt-ion'
        #   Configuration.longify(:opt_ion, false, false)      # => '--opt_ion'
        #
        def longify(str, switch_notation=false, hyphenize=true)
          str = str.to_s
          str = "--#{str}" unless str.index("--")
          str.gsub!(/_/, '-') if hyphenize
          
          raise "invalid long option: #{str}" unless str =~ LONG_REGEXP
          
          if switch_notation && $1.nil?
            str = "--[no-]#{$2}"
          end

          str
        end
      end
      
      attr_accessor :name
      attr_accessor :properties
      attr_reader :duplicable
      attr_reader :getter
      attr_reader :setter

      def initialize(name, default=nil, properties=nil, getter=name, setter="#{name}=")
        @name = name
        @properties = properties
        self.default = default
        self.getter = getter
        self.setter = setter
      end
      
      # Sets the default value for self and determines if the
      # default is duplicable (ie not nil, true, false, Symbol, 
      # Numeric, and responds_to?(:dup)).
      def default=(value)
        @duplicable = case value
        when nil, true, false, Symbol, Numeric then false
        else value.respond_to?(:dup)
        end
        
        @default = value.freeze
      end
      
      # Returns the default value, or a duplicate of the default
      # value if specified and the default value is duplicable.
      def default(duplicate=true)
        duplicate && duplicable ? @default.dup : @default
      end
      
      # Sets the getter for self.  The getter is symbolized.
      def getter=(value)
        @getter = value.to_sym
      end
      
      # Sets the setter for self.  The setter is symbolized.
      def setter=(value)
        @setter = value.to_sym
      end
      
      def empty?
        self.to_str.empty?
      end
      
      def to_str
        ""
      end
      
      def to_option_parser_argv
        argv = []
        argv << Configuration.shortify(short) if short = property(:short)
        long = Configuration.longify(property(:long) || name)

        argv << case property(:arg)
        when :optional 
          "#{long} [#{property(:arg_name) || name.to_s.upcase}]"
        when :switch 
          Configuration.longify(long, true)
        when :flag
          long
        when :list 
          "#{long} x,y,z"
        else # assume mandatory
          "#{long} #{property(:arg_name) || name.to_s.upcase}"
        end
        
        argv << self
        argv  
      end
      
      # True if another is a kind of Configuration and all attributes are equal.
      def ==(another)
        another.kind_of?(Configuration) && 
        self.name == another.name &&
        self.properties == another.properties &&
        self.default(false) == another.default(false) &&
        self.getter == another.getter &&
        self.setter == another.setter
      end
      
      protected
      
      def property(name)
        properties ? properties[name] : nil
      end
    end
  end
end