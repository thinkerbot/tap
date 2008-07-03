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
      attr_reader :duplicable
      attr_reader :reader
      attr_reader :writer
      
      attr_accessor :line
      attr_accessor :desc
      
      attr_accessor :arg_name
      attr_accessor :arg_type
      attr_accessor :long
      attr_accessor :short
      
      ATTRIBUTES = [:reader, :writer, :line, :desc, :arg_name, :arg_type, :long, :short]

      def initialize(name, default=nil, attributes={})
        @name = name
        self.default = default
        
        self.reader = name
        self.writer = "#{name}="
        self.attributes = attributes
      end
      
      def attributes=(attributes)
        attributes.each_pair do |key, value|
          case key
          when *ATTRIBUTES
            self.send("#{key}=", value)
          else
            raise ArgumentError.new("unknown or unsettable attribute: #{key}")
          end
        end
      end
      
      def attributes(*exclusions)
        attributes = {}
        ATTRIBUTES.each do |key|
          next if exclusions.include?(key)
          attributes[key] = self.send(key)
        end
        attributes
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
      
      def empty?
        # Hack to allow Configuration to act as it's own description
        # in OptionParser
        to_str.empty?
      end
      
      def to_str
        desc.to_s
      end
      
      def to_option_parser_argv
        argv = []
        argv << Configuration.shortify(short) if short
        long = Configuration.longify(long || name)

        argv << case arg_type
        when :optional 
          "#{long} [#{arg_name || name.to_s.upcase}]"
        when :switch 
          Configuration.longify(long, true)
        when :flag
          long
        when :list
          "#{long} a,b,c"
        else # assume mandatory
          "#{long} #{arg_name || name.to_s.upcase}"
        end
        
        argv << self
        argv  
      end
      
      # True if another is a kind of Configuration and all attributes are equal.
      def ==(another)
        another.kind_of?(Configuration) && 
        self.name == another.name &&
        self.attributes(:line, :desc) == another.attributes(:line, :desc) &&
        self.default(false) == another.default(false)
      end
      
    end
  end
end