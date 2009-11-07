require 'configurable'
require 'tap/app/index'

module Tap
  class App
    
    # Api implements the application interface described in the
    # API[link:files/doc/API.html] document, and provides additional
    # functionality shared by the Tap base classes.
    #
    # === Inheritance
    # :startdoc:::-
    #
    # Api is designed so that subclasses are the base for a type of resource
    # (ex Tap::Task, Tap::Join, Tap::Middleware).  Inheritance automatically
    # sets up the +type+ and +desc+ class methods according to the basename of
    # the Api subclass; all further subclasses inherit these methods their
    # parent.
    #
    # For example the type of Tap::Task and all subclasses of Tap::Task is
    # 'task' and similarly the type of Tap::Join and all Join subclasses is
    # 'join'.  If we make an example resource:
    #
    #   # Example::example desc is set to access this string
    #   class Example < Api
    #   end
    #
    #   Example.type        # => "example"
    #   Example.desc.to_s   # => "desc is set to access this string"
    #
    #   # Subclass::example the subclass also is also an 'example'
    #   class Subclass < Example
    #   end
    #
    #   Subclass.type        # => "example"
    #   Subclass.desc.to_s   # => "the subclass also is also an 'example'"
    #
    # Type can be manually set when this heruistic is inappropriate, but note
    # that desc will also need to be reset using this pattern:
    #
    #   # Alt::not_alt this is the description...
    #   # Alt::alt     and not this.
    #   class Alt < Api
    #     @type = "not_alt"
    #     lazy_attr(:desc, @type)
    #   end
    #
    #   Alt.type        # => "not_alt"
    #   Alt.desc.to_s   # => "this is the description..."
    #
    # :startdoc:::+
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
        def parser
          opts = ConfigParser.new
          
          unless configurations.empty?
            opts.separator "configurations:"
            opts.add(configurations)
            opts.separator ""
          end

          opts.separator "options:"
        
          # add option to print help
          opts.on("-h", "--help", "Print this help") do
            puts "#{self}#{desc.empty? ? '' : ' -- '}#{desc.to_s}"
            puts help
            puts opts
            exit
          end
          
          opts
        end
        
        # Parses the argv into an instance of self.  Internally parse parses
        # an argh then calls build, but there is no requirement that this
        # occurs in subclasses.
        def parse(argv=ARGV, app=Tap::App.instance)
          parse!(argv.dup, app)
        end
      
        # Same as parse, but removes arguments destructively.
        def parse!(argv=ARGV, app=Tap::App.instance)
          parser = self.parser
          parser.parse!(argv, :add_defaults => false)
          
          build({'config' => parser.nested_config}, app)
        end
      
        # Returns an instance of self.  By default build calls new with the
        # configurations specified by spec['config'], and app.
        def build(spec={}, app=Tap::App.instance)
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
      end
    
      include Configurable
      include Signals
      
      # The App receiving self during enq
      attr_reader :app
      
      # The default index signal
      signal nil, :class => Index
      
      def initialize(config={}, app=Tap::App.instance)
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
        {'config' => config}
      end
    end
  end
end