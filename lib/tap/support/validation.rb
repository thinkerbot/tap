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
      #
      #   string.class              # => Proc
      #   string.call('str')        # => 'str'
      #   string.call(:sym)         # => ValidationError
      #
      def string(); STRING; end
      STRING = check(String)
      
      # Returns a block that checks the input is a symbol.
      # String inputs are loaded as yaml first.
      #
      #   symbol.class              # => Proc
      #   symbol.call(:sym)         # => :sym
      #   symbol.call(':sym')       # => :sym
      #   symbol.call('str')        # => ValidationError
      #
      def symbol(); SYMBOL; end
      SYMBOL = yamlize_and_check(Symbol)
      
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

      # Returns a block that checks the input is an array.
      # String inputs are loaded as yaml first.
      #
      #   array.class               # => Proc
      #   array.call([1,2,3])       # => [1,2,3]
      #   array.call('[1, 2, 3]')   # => [1,2,3]
      #   array.call('str')         # => ValidationError
      #
      def array(); ARRAY; end
      ARRAY = yamlize_and_check(Array)

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
      #   hash.call('str')               # => ValidationError
      #
      def hash(); HASH; end
      HASH = yamlize_and_check(Hash)
      
      # Returns a block that checks the input is an integer.
      # String inputs are loaded as yaml first.
      #
      #   integer.class             # => Proc
      #   integer.call(1)           # => 1
      #   integer.call('1')         # => 1
      #   integer.call(1.1)         # => ValidationError
      #   integer.call('str')       # => ValidationError
      #
      def integer(); INTEGER; end
      INTEGER = yamlize_and_check(Integer)
      
      # Returns a block that checks the input is a float.
      # String inputs are loaded as yaml first.
      #
      #   float.class               # => Proc
      #   float.call(1.1)           # => 1.1
      #   float.call('1.1')         # => 1.1
      #   float.call(1)             # => ValidationError
      #   float.call('str')         # => ValidationError
      #
      def float(); FLOAT; end
      FLOAT = yamlize_and_check(Float)
      
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
    end
  end
end