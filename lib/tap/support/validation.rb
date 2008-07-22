module Tap
  module Support
    
    # Validation generates blocks for common validations/processing of 
    # configurations set through Configurable.  These blocks can be passed
    # to the config declarations using an ampersand (&).
    #
    # See the 'Configuration' section in the Tap::Task documentation for
    # more details on how Validation works in practice.
    module Validation
      
      # Raised when Validation blocks fail.
      class ValidationError < ArgumentError
        def initialize(input, validations)
          super case 
          when validations.empty?
            "no validations specified"
          else 
            validation_str = PP.singleline_pp(validations, "")
            PP.singleline_pp(input, "expected #{validation_str} but was: ")
          end
        end
      end
      
      # Raised when yamlization fails.
      class YamlizationError < ArgumentError
        def initialize(input, error)
          super "#{error} ('#{input}')"
        end
      end
      
      module_function
      
      # Yaml conversion and checker.  Valid if any of the validations
      # match in a case statement.  Otherwise raises an error.
      
      # Returns input if any of the validations match any of the
      # inputs, as in a case statement.  Raises a ValidationError 
      # otherwise.  For example:
      #
      #   validate(10, [Integer, nil])
      #
      # Does the same as:
      #
      #   case 10
      #   when Integer, nil then input
      #   else raise ValidationError.new(...)
      #   end
      #
      # Note the validations input must be an Array or nil; 
      # validate will raise an ArgumentError otherwise.  
      # All inputs are considered VALID if validations == nil.
      def validate(input, validations)
        case validations
        when Array
        
          case input
          when *validations then input
          else raise ValidationError.new(input, validations)
          end
          
        when nil then input
        else raise ArgumentError.new("validations must be nil, or an array of valid inputs")
        end
      end
      
      # Attempts to load the input as YAML.  Raises a YamlizationError
      # for errors.
      def yamlize(input)
        begin
          YAML.load(input)
        rescue
          raise YamlizationError.new(input, $!.message)
        end
      end
      
      # Returns a block that calls validate using the block input
      # and the input validations.  Raises an error if no validations
      # are specified.
      def check(*validations)
        raise ArgumentError.new("no validations specified") if validations.empty?
        lambda {|input| validate(input, validations) }
      end
    
      # Returns a block that loads input strings as YAML, then
      # calls validate with the result and the input validations.
      # Non-string inputs are not converted.
      #
      #   b = yaml(Integer, nil)
      #   b.class                 # => Proc
      #   b.call(1)               # => 1
      #   b.call("1")             # => 1
      #   b.call(nil)             # => nil
      #   b.call("str")           # => ValidationError
      #
      # If no validations are specified, the result will be 
      # returned without validation.
      def yaml(*validations)
        lambda do |input|
          res = input.kind_of?(String) ? yamlize(input) : input
          validations.empty? ? res : validate(res, validations)
        end
      end
      
      # Returns a block loads a String input as YAML then
      # validates the result is valid using the input
      # validations.  If the input is not a String, the
      # input is validated directly.
      def yamlize_and_check(*validations)
        lambda do |input|
          input = yamlize(input) if input.kind_of?(String)
          validate(input, validations)
        end
      end
      
      # Returns a block that checks the input is a string.
      # Moreover, strings are re-evaluated as string 
      # literals using %Q. 
      #
      #   string.class              # => Proc
      #   string.call('str')        # => 'str'
      #   string.call('\n')         # => "\n"
      #   string.call("\n")         # => "\n"
      #   string.call("%s")         # => "%s"
      #   string.call(nil)          # => ValidationError
      #   string.call(:sym)         # => ValidationError
      #
      def string(); STRING; end
      STRING = lambda do |input|
        input = validate(input, [String])
        eval %Q{"#{input}"}
      end
      
      # Same as string but allows nil.  Note the special
      # behavior of the nil string '~' -- rather than
      # being treated as a string, it is processed as nil
      # to be consistent with the other [class]_or_nil
      # methods.
      #
      #   string_or_nil.call('~')   # => nil
      #   string_or_nil.call(nil)   # => nil
      def string_or_nil(); STRING_OR_NIL; end
      STRING_OR_NIL = lambda do |input|
        input = validate(input, [String, nil])
        case input
        when nil, '~' then nil 
        else eval %Q{"#{input}"}
        end
      end
      
      # Returns a block that checks the input is a symbol.
      # String inputs are loaded as yaml first.
      #
      #   symbol.class              # => Proc
      #   symbol.call(:sym)         # => :sym
      #   symbol.call(':sym')       # => :sym
      #   symbol.call(nil)          # => ValidationError
      #   symbol.call('str')        # => ValidationError
      #
      def symbol(); SYMBOL; end
      SYMBOL = yamlize_and_check(Symbol)
      
      # Same as symbol but allows nil:
      #
      #   symbol_or_nil.call('~')   # => nil
      #   symbol_or_nil.call(nil)   # => nil
      def symbol_or_nil(); SYMBOL_OR_NIL; end
      SYMBOL_OR_NIL = yamlize_and_check(Symbol, nil)
      
      # Returns a block that checks the input is true, false or nil.
      # String inputs are loaded as yaml first.
      #
      #   boolean.class             # => Proc
      #   boolean.call(true)        # => true
      #   boolean.call(false)       # => false
      #   boolean.call(nil)         # => nil
      #
      #   boolean.call('true')      # => true
      #   boolean.call('yes')       # => true
      #   boolean.call('FALSE')     # => false
      #
      #   boolean.call(1)           # => ValidationError
      #   boolean.call("str")       # => ValidationError
      #
      def boolean(); BOOLEAN; end
      BOOLEAN = yamlize_and_check(true, false, nil)
      
      def switch(); SWITCH; end
      SWITCH = yamlize_and_check(true, false, nil)
      
      def flag(); FLAG; end
      FLAG = yamlize_and_check(true, false, nil)

      # Returns a block that checks the input is an array.
      # String inputs are loaded as yaml first.
      #
      #   array.class               # => Proc
      #   array.call([1,2,3])       # => [1,2,3]
      #   array.call('[1, 2, 3]')   # => [1,2,3]
      #   array.call(nil)           # => ValidationError
      #   array.call('str')         # => ValidationError
      #
      def array(); ARRAY; end
      ARRAY = yamlize_and_check(Array)
      
      # Same as array but allows nil:
      #
      #   array_or_nil.call('~')    # => nil
      #   array_or_nil.call(nil)    # => nil
      def array_or_nil(); ARRAY_OR_NIL; end
      ARRAY_OR_NIL = yamlize_and_check(Array, nil)
      
      def list(); LIST; end
      LIST = lambda do |input|
        if input.kind_of?(String)
          input = case processed_input = yamlize(input)
          when Array then processed_input
          else input.split(/,/).collect {|arg| yamlize(arg) }
          end
        end
        
        validate(input, [Array])
      end

      # Returns a block that checks the input is a hash.
      # String inputs are loaded as yaml first.
      #
      #   hash.class                     # => Proc
      #   hash.call({'key' => 'value'})  # => {'key' => 'value'}
      #   hash.call('key: value')        # => {'key' => 'value'}
      #   hash.call(nil)                 # => ValidationError
      #   hash.call('str')               # => ValidationError
      #
      def hash(); HASH; end
      HASH = yamlize_and_check(Hash)
      
      # Same as hash but allows nil:
      #
      #   hash_or_nil.call('~')          # => nil
      #   hash_or_nil.call(nil)          # => nil
      def hash_or_nil(); HASH_OR_NIL; end
      HASH_OR_NIL = yamlize_and_check(Hash, nil)
      
      # Returns a block that checks the input is an integer.
      # String inputs are loaded as yaml first.
      #
      #   integer.class             # => Proc
      #   integer.call(1)           # => 1
      #   integer.call('1')         # => 1
      #   integer.call(1.1)         # => ValidationError
      #   integer.call(nil)         # => ValidationError
      #   integer.call('str')       # => ValidationError
      #
      def integer(); INTEGER; end
      INTEGER = yamlize_and_check(Integer)
      
      # Same as integer but allows nil:
      #
      #   integer_or_nil.call('~')  # => nil
      #   integer_or_nil.call(nil)  # => nil
      def integer_or_nil(); INTEGER_OR_NIL; end
      INTEGER_OR_NIL = yamlize_and_check(Integer, nil)
      
      # Returns a block that checks the input is a float.
      # String inputs are loaded as yaml first.
      #
      #   float.class               # => Proc
      #   float.call(1.1)           # => 1.1
      #   float.call('1.1')         # => 1.1
      #   float.call('1.0e+6')      # => 1e6
      #   float.call(1)             # => ValidationError
      #   float.call(nil)           # => ValidationError
      #   float.call('str')         # => ValidationError
      #
      def float(); FLOAT; end
      FLOAT = yamlize_and_check(Float)
      
      # Same as float but allows nil:
      #
      #   float_or_nil.call('~')    # => nil
      #   float_or_nil.call(nil)    # => nil
      def float_or_nil(); FLOAT_OR_NIL; end
      FLOAT_OR_NIL = yamlize_and_check(Float, nil)
      
      # Returns a block that checks the input is a number.
      # String inputs are loaded as yaml first.
      #
      #   num.class               # => Proc
      #   num.call(1.1)           # => 1.1
      #   num.call(1)             # => 1
      #   num.call(1e6)           # => 1e6
      #   num.call('1.1')         # => 1.1
      #   num.call('1.0e+6')      # => 1e6
      #   num.call(nil)           # => ValidationError
      #   num.call('str')         # => ValidationError
      #
      def num(); NUMERIC; end
      NUMERIC = yamlize_and_check(Numeric)
      
      # Same as num but allows nil:
      #
      #   num_or_nil.call('~')    # => nil
      #   num_or_nil.call(nil)    # => nil
      def num_or_nil(); NUMERIC_OR_NIL; end
      NUMERIC_OR_NIL = yamlize_and_check(Numeric, nil)
      
      # Returns a block that checks the input is a regexp.
      # String inputs are converted to regexps using
      # Regexp#new.
      #
      #   regexp.class              # => Proc
      #   regexp.call(/regexp/)     # => /regexp/
      #   regexp.call('regexp')     # => /regexp/
      #
      #   # use of ruby-specific flags can turn on/off 
      #   # features like case insensitive matching
      #   regexp.call('(?i)regexp') # => /(?i)regexp/
      #
      def regexp(); REGEXP; end
      REGEXP = lambda do |input|
        input = Regexp.new(input) if input.kind_of?(String)
        validate(input, [Regexp])
      end
      
      # Same as regexp but allows nil. Note the special
      # behavior of the nil string '~' -- rather than
      # being converted to a regexp, it is processed as 
      # nil to be consistent with the other [class]_or_nil
      # methods.
      #
      #   regexp_or_nil.call('~')   # => nil
      #   regexp_or_nil.call(nil)   # => nil
      def regexp_or_nil(); REGEXP_OR_NIL; end
      REGEXP_OR_NIL = lambda do |input|
        input = case input
        when nil, '~' then nil
        when String then Regexp.new(input)
        else input
        end
        
        validate(input, [Regexp, nil])
      end
      
    end
  end
end