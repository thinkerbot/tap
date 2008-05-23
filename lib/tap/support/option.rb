module Tap
  module Support
    class Option
      class << self
        SHORT_REGEXP = /^-[A-z]$/
        
        # Turns the input string into a short-format option.  Raises
        # an error if the option does not match SHORT_REGEXP.
        #
        #   Option.shortify("-o")   # => '-o'
        #   Option.shortify(:o)     # => '-o'
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
        #   Option.longify("--opt")                     # => '--opt'
        #   Option.longify(:opt)                        # => '--opt'
        #   Option.longify(:opt, true)                  # => '--[no-]opt'
        #   Option.longify(:opt_ion)                    # => '--opt-ion'
        #   Option.longify(:opt_ion, false, false)      # => '--opt_ion'
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
      
      # properties should be NIL!
      def initialize(name, default=nil, properties={})
        @name = name
        @properties = properties
        self.default = default
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
      
      # def to_getopt_long_argv
      #   argv = []
      #   argv << Option.longify(properties[:long] || name)
      #   argv << Option.shortify(properties[:short] || name[0,1])
      #   
      #   argv << case properties[:arg]
      #   when :optional 
      #     GetoptLong::OPTIONAL_ARGUMENT
      #   when :flag
      #     GetoptLong::NO_ARGUMENT
      #   else # assume mandatory
      #     GetoptLong::REQUIRED_ARGUMENT
      #   end
      #   
      #   argv
      # end
      
      def property(name)
        properties ? properties[name] : nil
      end
        
      def to_option_parser_argv
        argv = []
        argv << Option.shortify(property(:short) || name.to_s[0,1])
        long = Option.longify(property(:long) || name)

        argv << case property(:arg)
        when :optional 
          "#{long} [#{property(:arg_name) || name.to_s.upcase}]"
        when :switch 
          Option.longify(long, true)
        when :flag
          long
        when :list 
          "#{long} x,y,z"
        else # assume mandatory
          "#{long} #{property(:arg_name) || name.to_s.upcase}"
        end
        
        argv  
      end
      
      # True if another is a kind of Option and all attributes are equal.
      def ==(another)
        another.kind_of?(Option) && 
        self.name == another.name &&
        self.properties == another.properties &&
        self.default(false) == another.default(false)
      end
    end
  end
end