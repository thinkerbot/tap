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
        
        # Nest the return of the block in the nesting lines.
        #
        #  nest([["\nmodule Some", "end\n"],["module Nested", "end"]]) { "class Const\nend" }
        #  # => %Q{
        #  # module Some
        #  #   module Nested
        #  #     class Const
        #  #     end
        #  #   end
        #  # end
        #  # }
        #
        def nest(nesting, indent="  ", line_sep="\n")
          content = yield
          return content if nesting.empty?
          
          depth = nesting.length
          lines = [indent * depth + content.gsub(/#{line_sep}/, line_sep + indent * depth)]

          nesting.reverse_each do |(start_line, end_line)|
            depth -= 1
            lines.unshift(indent * depth + start_line)
            lines << (indent * depth + end_line)
          end

          lines.join(line_sep)
        end
        
        # Nest the return of the block in the nesting module.
        #
        #  module_nest('Some::Nested') { "class Const\nend" }
        #  # => %Q{
        #  # module Some
        #  #   module Nested
        #  #     class Const
        #  #     end
        #  #   end
        #  # end
        #  # }.strip
        #
        def module_nest(const_name, indent="  ", line_sep="\n")
          nesting = const_name.split(/::/).collect do |name|
            ["module #{name}", "end"]
          end
          
          nest(nesting, indent, line_sep) { yield }
        end
      end
      
      include Utils
      
      # Initialized a new Templater.  An ERB or String may be provided as the
      # template.  If a String is provided, it will be used to initialize an
      # ERB with a trim_mode of "<>".
      def initialize(template, attributes={})
        @template = case template
        when ERB 
          if template.instance_variable_get(:@src).index('_erbout =') != 0
            raise ArgumentError, "Templater does not work with ERB templates where eoutvar != '_erbout'"
          end
          template
        when String then ERB.new(template, nil, "<>")
        else raise ArgumentError, "cannot convert #{template.class} into an ERB template"
        end
        
        src = @template.instance_variable_get(:@src)
        @template.instance_variable_set(:@src, "self." + src) 

        super(attributes)
      end
      
      def _erbout
        self
      end
      
      def _erbout=(input)
        @_erbout = input
      end
      
      def redirect
        current = @_erbout
        @_erbout = ""
        result = yield(@_erbout)
        @_erbout = current
        concat(result)
      end
      
      def concat(input)
        @_erbout << input
      end
      
      # Build the template.  All methods of self will be 
      # accessible in the template.
      def build
        @template.result(binding)
        @_erbout
      end
      
    end
  end
end