module Tap
  class App
    class Api
      class << self
      
        def inherited(child)
          super
        
          unless child.respond_to?(:desc)
            child.lazy_attr(:desc, File.basename(child.to_s.underscore))
          end
        end
      
        # Parses the argv into an instance of self.  By default parse 
        # parses an argh then calls instantiate, but there is no requirement
        # that this occurs in subclasses.
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
            puts "#{self}#{desc.empty? ? '' : ' -- '}#{desc.to_s}"
            puts help
            puts opts
            exit
          end
        
          args = opts.parse!(argv, :add_defaults => false)
          instantiate({:config => opts.nested_config}, app)
        end
      
        def instantiate(spec={}, app=Tap::App.instance)
          new(spec[:config] || {}, app)
        end
      
        def help
          lines = desc.kind_of?(Lazydoc::Comment) ? desc.wrap(77, 2, nil) : []
          lines.collect! {|line| "  #{line}"}
          unless lines.empty?
            line = '-' * 80
            lines.unshift(line)
            lines.push(line)
          end

          lines.join("\n")
        end
      
        def action(method, &block)
        end
      end
    
      include Configurable
    
      def api(spec)
      end
    end
  end
end