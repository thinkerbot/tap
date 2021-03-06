require 'tap/app'

module Tap
  class App
    
    # Api implements the application interface described in the
    # API[link:files/doc/API.html] document, and provides additional
    # functionality shared by the Tap base classes.
    class Api
      class << self
        
        # The type of the class.
        attr_reader :type
        
        def inherited(child) # :nodoc:
          super
          
          type = self.type || child.to_s.split('::').last.downcase
          child.instance_variable_set(:@type, type)
          
          unless child.respond_to?(:desc)
            child.lazy_attr(:desc, type)
          end
        end
      
        # Returns a ConfigParser setup to parse the configurations for the
        # subclass. The parser is also setup to print usage (using the desc
        # for the subclass) and exit for the '-h' and '--help' options.
        #
        # The parse method uses parser by default, so subclasses can simply
        # modify parser and ensure parse still works correctly.
        def parser(app)
          opts = ConfigParser.new
          
          unless configurations.empty?
            opts.separator "configurations:"
            opts.add(configurations)
            opts.separator ""
          end

          opts.separator "options:"
        
          # add option to print help
          opts.on("--help", "Print this help") do
            lines = ["#{self}#{desc.empty? ? '' : ' -- '}#{desc.to_s}"]
            lines << help
            lines << "usage: tap #{to_s.underscore} #{respond_to?(:args) ? args : nil}"
            lines << nil
            lines << opts
            raise lines.join("\n")
          end
          
          opts
        end
        
        def parse(argv=ARGV, app=Tap::App.current, &block)
          parse!(argv.dup, app, &block)
        end
        
        # Parses the argv into an instance of self.  Internally parse parses
        # an argh then calls build, but there is no requirement that this
        # occurs in subclasses.
        #
        # Returns the instance.  If a block is given, the instance and any
        # remaining arguments will be yielded to it.
        def parse!(argv=ARGV, app=Tap::App.current)
          parser = self.parser(app)
          args = parser.parse!(argv, :add_defaults => false)
          obj = build(convert_to_spec(parser, args), app)
          
          if block_given?
            yield(obj, args)
          else
            parser.warn_ignored_args(args)
            obj
          end
        end
        
        # Returns an instance of self.  By default build calls new with the
        # configurations specified by spec['config'], and app.
        def build(spec={}, app=Tap::App.current)
          new(spec['config'] || {}, app)
        end
      
        # Returns a help string that formats the desc documentation.
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
        
        protected
        
        def convert_to_spec(parser, args)
          {'config' => parser.nested_config}
        end
      end
    
      include Configurable
      include Signals
      
      define_signal :help, Help                     # signals help
      
      # The app for self
      attr_reader :app
      
      def initialize(config={}, app=Tap::App.current)
        @app = app
        initialize_config(config)
      end
      
      # By default associations returns nil.
      def associations
      end
      
      # By default to_spec returns a hash like {'config' => config} where
      # config is a stringified representation of the configurations for self.
      def to_spec
        config = self.config.to_hash {|hash, key, value| hash[key.to_s] = value }
        config.empty? ? {} : {'config' => config}
      end
      
      # Provides an abbreviated version of the default inspect, with only the
      # class, object_id, and configurations listed.
      def inspect
        "#<#{self.class.to_s}:#{object_id} #{config.to_hash.inspect} >"
      end
    end
  end
end