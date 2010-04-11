require 'tap/tasks/dump'
require 'tap/env'
require 'erb'

module Tap
  module Tasks
    # :startdoc::task render an object
    class Render < Tap::Tasks::Dump

      config :dir, :views
      config :path, 'obj.erb'
      
      attr_accessor :env
      
      def initialize(config={}, app=Tap::App.current, env=Tap::Env.instance)
        super(config, app)
        @env = env
      end
      
      # Renders the specified template as ERB using the options.  Options:
      #
      #   locals:: a hash of local variables used in the template
      #
      # The filename used to identify errors in an erb template to a specific
      def render(path, options={})
        # render template
        template = File.read(path)

        # assign locals to the render binding
        # this almost surely may be optimized...
        locals = options[:locals]
        binding = empty_binding

        locals.each_pair do |key, value|
          @assignment_value = value
          eval("#{key} = remove_instance_variable(:@assignment_value)", binding)
        end if locals

        erb = ERB.new(template, nil, "<>")
        erb.filename = path
        erb.result(binding)
      end
      
      # Dumps the object to io using obj.inspect
      def dump(obj, io)
        template_path = env.class_path(dir, obj, path) do |file|
          File.file?(file)
        end
        
        unless template_path
          raise "no template for: #{obj.class}"
        end
        
        io.puts render(template_path, :locals => {:obj => obj})
      end
      
      protected
      
      # Generates an empty binding to self without any locals assigned.
      def empty_binding # :nodoc:
        binding
      end
    end
  end
end