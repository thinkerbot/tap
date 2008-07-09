module Tap
  module Support
    class Configuration
      
      @@registry = {}

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

        def registry
          @@registry
        end
        
        def resolve(key, registration)
          return nil unless registration
          
          register_key, line_number = registration
          hash = registry[register_key][line_number]

          case hash
          when Hash
            hash[key]
          when Integer
            return nil unless File.exists?(register_key)
            registry[register_key] = parse_register(File.read(register_key), registry[register_key])
            registry[register_key][line_number][key]
          else nil
          end
        end
        
        def parse_register(str, line_numbers)
          # scanner = StringScanner.new(str)
          # current = 1
          # line_numbers.collect do |line_number|
          #   hash = {}
          #   
          #   scanner.skip_until(/(.*?\n){#{line_number-current}}/)
          #   hash[:desc] = ""
          #   
          #   hash[:summary] = if scanner.skip(/^[ \t]*config(.*)#(.*)$/)
          #     # params = scanner[2]
          #     scanner[2].strip
          #   else
          #     nil
          #   end
          #   
          #   current = line_number
          #   hash
          # end
          
          lines = str.split(/\r?\n/)
          line_numbers.collect do |line_number|
            hash = {}
           
            hash[:summary] = (lines[line_number-1] =~ /^[ \t]*config(.*)#(.*)$/) ? $2.strip : nil
            hash[:desc] = ""  # drill backwards for comment lines
            hash
          end
        end
        
      end
      
      attr_reader :name
      attr_reader :reader
      attr_reader :writer
      attr_reader :duplicable
      
      def initialize(name, default=nil, attributes={})
        @name = name
        @registration = nil
        self.default = default
        
        self.reader = name
        self.writer = "#{name}="
        self.attributes = attributes
      end
      
      def attributes=(attributes)
        @attributes = attributes.delete_if {|key, value| value == nil}
        self.reader = attributes.delete(:reader) if attributes[:reader]
        self.writer = attributes.delete(:writer) if attributes[:writer]
        
        @attributes = EMPTY_ATTRS if @attributes.empty?
      end
      
      def attributes
        attributes = {}
        [:reader, :writer, :arg_name, :arg_type, :long, :short, :desc, :summary].each do |key|
          attributes[key] = send(key)
        end
        attributes
      end
      
      def register(source_file, line_number)
        key = File.expand_path(source_file)
        array = Configuration.registry[key] ||= []
        
        index = array.index(line_number)
        if index == nil
          index = array.length
          array << (line_number)
        end
        
        @registration = [key, index]
      end
      
      def line_number
        # won't work after resolution!
        @registration ? (self.class.registry[@registration[0]][@registration[1]]) : nil
      end
      
      def source_file
        @registration ? @registration[0] : nil
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
        @attributes[:arg_name] || name.to_s.upcase
      end
      
      def arg_type
        @attributes[:arg_type] || :mandatory
      end
      
      def long
        @attributes[:long] || name
      end
      
      def short
        @attributes[:short]
      end
      
      def summary
        @attributes[:summary] || self.class.resolve(:summary, @registration)
      end
      
      def desc
        @attributes[:desc] || self.class.resolve(:desc, @registration)
      end
      
      def empty?
        # Hack to allow Configuration to act as it's own description
        # in OptionParser
        to_str.empty?
      end
      
      def to_str
        summary.to_s
      end
      
      def to_option_parser_argv
        argv = []
        argv << Configuration.shortify(short) if short
        long = Configuration.longify(self.long)

        argv << case arg_type
        when :optional 
          "#{long} [#{arg_name}]"
        when :switch 
          Configuration.longify(self.long, true)
        when :flag
          long
        when :list
          "#{long} a,b,c"
        when :mandatory, nil
          "#{long} #{arg_name}"
        else
          raise "unknown arg_type: #{arg_type}"
        end
        
        argv << self # such that self acts as desc
        argv  
      end
      
      # True if another is a kind of Configuration and all attributes are equal.
      def ==(another)
        another.kind_of?(Configuration) && 
        self.name == another.name &&
        #self.attributes == another.attributes &&
        self.default(false) == another.default(false)
      end
      
      private
      
      EMPTY_ATTRS = {}.freeze
    end
  end
end