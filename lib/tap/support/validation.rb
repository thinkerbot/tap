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
          res = input.kind_of?(String) ? YAML.load(input) : input
          validations.empty? ? res : validate(res, validations)
        end
      end

      # Returns a block that converts an input into a boolean
      # using YAML (stringifying if needed), then validates 
      # the result to be true, false or nil.
      #
      #   boolean.class           # => Proc
      #   boolean.call(true)      # => true
      #   boolean.call(false)     # => false
      #   boolean.call(nil)       # => nil
      #
      #   # since the input is loaded as yaml, some variations...
      #   boolean.call('true')    # => true
      #   boolean.call('yes')     # => true
      #   boolean.call('FALSE')   # => false
      #
      #   boolean.call(1)               # => ValidationError
      #   boolean.call("str")           # => ValidationError
      #
      def boolean(); BOOLEAN; end
      BOOLEAN = lambda do |input|
        case input
        when true, false, nil then input
        else validate(YAML.load(input.to_s), [true, false, nil])
        end
      end
      
      def array(); ARRAY; end
      ARRAY = check(Array)
      
    end
  end
end