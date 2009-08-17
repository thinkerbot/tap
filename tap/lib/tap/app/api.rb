require 'configurable'
require 'tap/signals'

module Tap
  class App
    class Api
      class << self
        
        attr_reader :type
        
        def inherited(child)
          super
          
          type = self.type || child.to_s.split('::').last.downcase
          child.instance_variable_set(:@type, type)
          
          unless child.respond_to?(:desc)
            child.lazy_attr(:desc, type)
          end
        end
      
        def parser
          opts = ConfigParser.new
          opts.separator "configurations:"
          opts.add(configurations)
        
          # add option to print help
          opts.on("-h", "--help", "Print this help") do
            puts "#{self}#{desc.empty? ? '' : ' -- '}#{desc.to_s}"
            puts help
            puts opts
            exit
          end
          
          opts
        end
        
        # Parses the argv into an instance of self.  By default parse 
        # parses an argh then calls build, but there is no requirement
        # that this occurs in subclasses.
        def parse(argv=ARGV, app=Tap::App.instance)
          parse!(argv.dup, app)
        end
      
        # Same as parse, but removes arguments destructively.
        def parse!(argv=ARGV, app=Tap::App.instance)
          parser = self.parser
          args = parser.parse!(argv, :add_defaults => false)
          [build({'config' => parser.nested_config}, app), args]
        end
      
        def build(spec={}, app=Tap::App.instance)
          new(spec['config'] || {}, app)
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
      end
    
      include Configurable
      include Signals
      
      def associations
      end
      
      def to_spec
        {'config' => config.to_hash}
      end
    end
  end
end