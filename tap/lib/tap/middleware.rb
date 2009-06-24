require 'configurable'

module Tap
  class Middleware
    class << self
      
      # Instantiates an instance of self and causes app to use the instance
      # as middleware.
      def parse(argv=ARGV, app=Tap::App.instance)
        parse!(argv.dup, app)
      end
      
      # Same as parse, but removes arguments destructively.
      def parse!(argv=ARGV, app=Tap::App.instance)
        opts = ConfigParser.new
        opts.separator "configurations:"
        opts.add(configurations)
        
        # add option to print help
        opts.on("--help", "Print this help") do
          lines = desc.kind_of?(Lazydoc::Comment) ? desc.wrap(77, 2, nil) : []
          lines.collect! {|line| "  #{line}"}
          unless lines.empty?
            line = '-' * 80
            lines.unshift(line)
            lines.push(line)
          end

          puts "#{self}#{desc.empty? ? '' : ' -- '}#{desc.to_s}"
          puts lines.join("\n")
          puts opts
          exit
        end
        
        args = opts.parse!(argv, :add_defaults => false)
        instantiate({:config => opts.nested_config}, app)
      end
      
      # Instantiates an instance of self and causes app to use the instance
      # as middleware.
      def instantiate(argh, app=Tap::App.instance)
        app.use(self, argh[:config] || {})
      end
    end
    
    include Configurable
    
    lazy_attr :desc, 'join'
    
    # The call stack.
    attr_reader :stack

    def initialize(stack, config={})
      @stack = stack
      initialize_config(config)
    end
    
    # Returns the app at the base of the stack.
    def app
      @app ||= begin
        current = stack
        until current.kind_of?(App::Stack)
          current = current.stack
        end
        current.app
      end
    end
    
    # By default call simply calls stack with the node and inputs.
    def call(node, inputs=[])
      stack.call(node, inputs)
    end
  end
end