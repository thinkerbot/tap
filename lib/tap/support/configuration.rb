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
      
      attr_reader :name
      attr_reader :reader
      attr_reader :writer
      attr_reader :duplicable
      attr_reader :attributes
 
      def initialize(name, default=nil, options={})
        @name = name
        self.default = default
        
        self.reader = options.delete(:reader) || name
        self.writer = options.delete(:writer) || "#{name}="
        @attributes = options
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
      
      # Sets the reader for self.  The reader is symbolized.
      def reader=(value)
        @reader = value.to_sym
      end
      
      # Sets the writer for self.  The writer is symbolized.
      def writer=(value)
        @writer = value.to_sym
      end
      
      def arg_name
        attributes[:arg_name] || name.to_s.upcase
      end
      
      def arg_type
        attributes[:arg_type] || :mandatory
      end
      
      def long(switch_notation=false, hyphenize=true)
        Configuration.longify(attributes[:long] || name.to_s, switch_notation, hyphenize)
      end
      
      def short
        attributes[:short] ? Configuration.shortify(attributes[:short]) : nil
      end
      
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
      
    end
  end
end