module Tap
  module Support
    
    # Templater is a convenience class for creating ERB templates.  As
    # an OpenStruct, attributes can be assigned/unassigned at will to
    # a Templater.  When the template is built, all the method of 
    # Templater (and hence all the assigned attributes) are available
    # in the template.
    #
    #   t = Templater.new( "key: <%= value %>")
    #   t.value = "default"
    #   t.build                 # => "key: default"
    #
    #   t.value = "another"
    #   t.build                 # => "key: another"
    #
    # Templater includes the Templater::Utils utility methods.
    class Templater < OpenStruct
      
      # Utility methods for Templater; mostly string manipulations
      # useful in creating documentation.
      module Utils
        
        # yamlize converts the object to YAML (using to_yaml), omitting
        # the header and final newline:
        #
      	#   {'key' => 'value'}.to_yaml           # => "--- \nkey: value\n"
      	#   yamlize {'key' => 'value'}           # => "key: value"
        def yamlize(object)
        	object.to_yaml[5...-1]
        end
      end
      
      include Utils
      
      def initialize(template, attributes={})
        @template = case template
        when ERB then template
        when String then ERB.new(template, nil, "<>")
        else raise ArgumentError.new("cannot convert #{template.class} into an ERB template")
        end
        
        super(attributes)
      end
      
      # Build the template.  All methods of self will be 
      # accessible in the template.
      def build
        @template.result(binding)
      end
    end
  end
end