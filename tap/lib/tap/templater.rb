require 'ostruct'
autoload(:ERB, 'erb')
autoload(:YAML, 'yaml')

module Tap
  # Templater is a convenience class for creating ERB templates.  As
  # a subclass of OpenStruct, attributes can be assigned/unassigned
  # directly.  When the template is built, all the method of 
  # Templater (and hence all the assigned attributes) are available.
  #
  #   t = Templater.new( "key: <%= value %>")
  #   t.value = "default"
  #   t.build                 # => "key: default"
  #
  #   t.value = "another"
  #   t.build                 # => "key: another"
  #
  # Templater includes the Templater::Utils utility methods.
  #
  # === ERB Redirection
  #
  # Templater hooks into the ERB templating mechanism by providing itself 
  # as the ERB output target (_erbout).  ERB concatenates each line of an 
  # ERB template to _erbout, as can be seen here:
  #
  #   e = ERB.new("<%= 1 + 2 %>")
  #   e.src                   # => "_erbout = ''; _erbout.concat(( 1 + 2 ).to_s); _erbout"
  #
  # By setting itself as _erbout, instances of Templater can redirect 
  # output to a temporary target and perform string transformations.  
  # For example, redirection allows indentation of nested content:
  #
  #   template = %Q{
  #   # Un-nested content
  #   <% redirect do |target| %>
  #   # Nested content
  #   <% module_nest("Nesting::Module") { target } %>
  #   <% end %>
  #   }
  #
  #   t = Templater.new(template)
  #   t.build
  #   # => %Q{
  #   # # Un-nested content
  #   # module Nesting
  #   #   module Module
  #   #     # Nested content
  #   #     
  #   #   end
  #   # end}
  #
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
        object == nil ? "~" : YAML.dump(object)[4...-1].strip
      end
      
      # Comments out the string.
      def comment(str)
        str.split("\n").collect {|line| "# #{line}" }.join("\n")
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
    
    class << self
      
      # Builds the erb template with the specified attributes.
      def build(template,  attributes={}, filename=nil)
        new(template, attributes, filename).build
      end
    end
    
    include Utils
    
    # Initialized a new Templater.  An ERB or String may be provided as the
    # template.  If a String is provided, it will be used to initialize an
    # ERB with a trim_mode of "<>".
    def initialize(template, attributes={})
      @template = case template
      when ERB
        # matching w/wo the coding effectively checks @src
        # across ruby versions (encoding appears in 1.9)
        if template.instance_variable_get(:@src) !~ /^(#coding:US-ASCII\n)?_erbout =/
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
    
    # Returns self (not the underlying erbout storage that actually receives 
    # the output lines).  In the ERB context, this method directs erb outputs
    # to Templater#concat and into the redirect mechanism.
    def _erbout
      self
    end
    
    # Sets the underlying erbout storage to input.
    def _erbout=(input)
      @_erbout = input
    end
    
    unless RUBY_VERSION < "1.9"
      #-- TODO
      # check if this is still needed...
      def force_encoding(encoding)
        @_erbout.force_encoding(encoding)
        @_erbout
      end
    end
    
    # Redirects output of erb to the redirected_erbout string
    # for the duration of the block.  When redirect completes,
    # the redirected_erbout is concatenated to the main
    # erbout storage.
    def redirect # :yields: redirected_erbout
      current = @_erbout
      @_erbout = ""
      result = yield(@_erbout)
      @_erbout = current
      concat(result)
    end
    
    # Concatenates the specified input to the underlying erbout storage.
    def concat(input)
      @_erbout << input
    end
    
    # Build the template, setting the attributes and filename if specified.
    # All methods of self will be accessible in the template.
    def build(attrs=nil, filename=nil)
      attrs.each_pair do |key, value|
        send("#{key}=", value)
      end if attrs
      
      @template.filename = filename
      @template.result(binding)
      @_erbout
    end
  end
end