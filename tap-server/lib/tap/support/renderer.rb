autoload(:ERB, 'erb')

module Tap
  module Support
    autoload(:Intern, 'tap/support/intern')
    
    class Renderer
      class << self
        def intern(*args, &block)
          instance = new(*args)
          if block_given?
            instance.extend Support::Intern(:template_path)
            instance.template_path_block = block
          end
          instance
        end
      end
      
      # Path to the default_layout file.
      attr_accessor :default_layout
      
      def initialize(default_layout=nil)
        @default_layout = default_layout
      end
      
      # A hook for determining a template path from a thing passed to render.
      def template_path(thing)
        thing
      end
      
      def render(thing, options={})
        # lookup the template path
        path = template_path(thing)
        raise "no such thing: #{thing.inspect}" unless File.exists?(path)
        
        # render content
        template = File.read(path)
        content = case File.extname(path)
        when '.erb' then render_erb(template, options[:locals] || {})
        else template
        end
        
        # render content into layout
        layout = options.has_key?(:layout) ? options[:layout] : default_layout
        layout = default_layout if layout == true 
        layout ? render(layout, :locals => {:content => content}, :layout => false) : content
      end
      
      # Renders _path without a layout.
      def partial(path, options={})
        render("#{File.dirname(path)}/_#{File.basename(path)}", options.merge(:layout => false))
      end
      
      def render_erb(template, locals={})
        binding = erb_binding
        
        # assign locals to the erb binding
        # NOTE: this almost surely may be optimized...
        locals.each_pair do |key, value|
          @assignment_value = value
          eval("#{key} = remove_instance_variable(:@assignment_value)", binding)
        end
        
        ERB.new(template, nil, "<>").result(binding)
      end
      
      private
      
      # Generates an empty binding to self without any locals assigned.
      def erb_binding # :nodoc:
        binding
      end
    end
  end
end