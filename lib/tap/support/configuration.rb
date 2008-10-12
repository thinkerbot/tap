module Tap
  module Support
    
    # Represents a configuration declared by a Configurable class.
    class Configuration
      class << self
        
        # Matches a short option
        SHORT_OPTION = /^-[A-z]$/
        
        # Turns the input string into a short-format option.  Raises
        # an error if the option does not match SHORT_REGEXP.
        #
        #   Configuration.shortify("-o")   # => '-o'
        #   Configuration.shortify(:o)     # => '-o'
        #
        def shortify(str)
          str = str.to_s
          str = "-#{str}" unless str[0] == ?-
          raise "invalid short option: #{str}" unless str =~ SHORT_OPTION
          str
        end
        
        # Matches a long option
        LONG_OPTION = /^--(\[no-\])?([A-z][\w-]*)$/
        
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
          
          raise "invalid long option: #{str}" unless str =~ LONG_OPTION
          
          if switch_notation && $1.nil?
            str = "--[no-]#{$2}"
          end

          str
        end
      end
      
      # The name of the configuration
      attr_reader :name
      
      # The reader method, by default name
      attr_reader :reader
      
      # The writer method, by default name=
      attr_reader :writer
      
      # True if the default value may be duplicated
      attr_reader :duplicable
      
      # An array of optional metadata for self
      attr_reader :attributes
      
      # Initializes a new Configuration with the specified name and default
      # value.  Options may specify an alternate reader/writer; any
      # additional options are set as attributes.
      def initialize(name, default=nil, options={})
        @name = name
        self.default = default
        
        self.reader = options.has_key?(:reader) ? options.delete(:reader) : name
        self.writer = options.has_key?(:writer) ? options.delete(:writer) : "#{name}="
        @attributes = options
      end

      # Sets the default value for self and determines if the
      # default is duplicable.  Non-duplicable values include
      # nil, true, false, Symbol, Numeric, and any object that
      # does not respond to dup.
      def default=(value)
        @duplicable = case value
        when nil, true, false, Symbol, Numeric, Method then false
        else value.respond_to?(:dup)
        end
        
        @default = value.freeze
      end
      
      # Returns the default value, or a duplicate of the default
      # value if specified and the default value is duplicable.
      def default(duplicate=true)
        duplicate && duplicable ? @default.dup : @default
      end
      
      # Sets the reader for self.  The reader is symbolized,
      # but may also be set to nil.
      def reader=(value)
        @reader = value == nil ? value : value.to_sym
      end
      
      # Sets the writer for self.  The writer is symbolized,
      # but may also be set to nil.
      def writer=(value)
        @writer = value == nil ? value : value.to_sym
      end
      
      # The argument name for self: either attributes[:arg_name]
      # or name.to_s.upcase
      def arg_name
        attributes[:arg_name] || name.to_s.upcase
      end
      
      # The argument type for self: either attributes[:arg_type]
       # or :mandatory
      def arg_type
        attributes[:arg_type] || :mandatory
      end
      
      # The long version of name.
      def long(switch_notation=false, hyphenize=true)
        Configuration.longify(attributes[:long] || name.to_s, switch_notation, hyphenize)
      end
      
      # The short version of name.
      def short
        attributes[:short] ? Configuration.shortify(attributes[:short]) : nil
      end
      
      # The description for self: attributes[:desc]
      def desc
        attributes[:desc]
      end

      # True if another is a kind of Configuration with the same name,
      # default value, reader and writer; other attributes are NOT 
      # taken into account.
      def ==(another)
        another.kind_of?(Configuration) && 
        self.name == another.name &&
        self.reader == another.reader &&
        self.writer == another.writer &&
        self.default(false) == another.default(false)
      end
      
      # Returns self as an argv that can be used to register
      # an option with OptionParser.
      def to_optparse_argv
        argtype = case arg_type
        when :optional 
          "#{long} [#{arg_name}]"
        when :switch 
          long(true)
        when :flag
          long
        when :list
          "#{long} a,b,c"
        when :mandatory, nil
          "#{long} #{arg_name}"
        else
          raise "unknown arg_type: #{arg_type}"
        end

        [short, argtype, desc].compact
      end
      
    end
  end
end