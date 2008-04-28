autoload(:PP, 'pp')

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
          validation_str = PP.singleline_pp(validations, "")
          super PP.singleline_pp(input, "expected #{validation_str} but was: ")
        end
      end
      
      module_function
      
      # Yaml conversion and checker.  Valid if any of the validations
      # match in a case statement.  Otherwise raises an error.
      
      # Returns input if any of the validations match the input, as
      # in a case statement.  Raises a ValidationError otherwise.
      #
      # For example:
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
      def validate(input, validations)
        case input
        when *validations then input
        else
          raise ValidationError.new(input, validations)
        end
      end
      
      # Returns a block that calls validate using the block input
      # and the input validations.
      def check(*validations)
        lambda {|input| validate(input, validations) }
      end
    
      # Returns a block that loads input strings as YAML, then
      # calls validate with the result and the input validations.
      # If the block input is not a string, the block input is 
      # validated.
      #
      #   b = yaml(Integer, nil)
      #   b.class                 # => Proc
      #   b.call(1)               # => 1
      #   b.call("1")             # => 1
      #   b.call(nil)             # => nil
      #   b.call("str")           # => ValidationError
      #
      # Note: yaml is especially useful for validating configs
      # that may be specified as strings or as an actual object.
      def yaml(*validations)
        lambda do |input|
          res = input.kind_of?(String) ? YAML.load(input) : input
          validate(res, validations)
        end
      end
    end
  end
end