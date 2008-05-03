module Tap
  module Support
    class Templater < OpenStruct
      
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
 
      def build
        @template.result(binding)
      end
    end
  end
end