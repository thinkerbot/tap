require 'tap/task'

module Tap
  module Tasks
    # :startdoc::task insert into an array
    #
    # Insert supports a common workflow pattern of inserting variable
    # arguments into an otherwise static array.
    #
    #   % tap load moon -: insert goodnight %0 -: inspect
    #   ["goodnight", "moon"]
    #
    # The percent serves as a placeholder identifying the index of the
    # argument that will be inserted.  Unlike most tasks, command-line
    # arguments provided to insert define the insertion template rather than
    # inputs (ie they cannot be enqued or executed with -- or -!) so typically
    # inserts are used with joins or signals.
    #
    #   % tap insert goodnight %0 -: inspect -/enq 0 moon
    #   ["goodnight", "moon"]
    #
    # Arguments can be used more than once, as indicated.  The default value
    # will be used if the argument value at the given index is nil.
    #
    #   % tap load a -: insert %0 %0 %1 -: inspect
    #   ["a", "a", nil]
    #
    class Insert < Tap::Task 
      class << self
        def parse(argv=ARGV, app=Tap::App.current)
          super(argv, app, &nil)
        end
        
        def parse!(argv=ARGV, app=Tap::App.current)
          super(argv, app, &nil)
        end
        
        def build(spec={}, app=Tap::App.current)
          new(spec['template'], spec['config'], app)
        end
        
        def convert_to_spec(parser, args)
          template = args.dup
          args.clear
          
          {
            'config' => parser.nested_config,
            'template'  => template
          }
        end
      end
      
      config :placeholder, '%', :short => :p, &c.string  # argument placeholder
      config :default, nil                               # default insert value
      
      attr_reader :template
      
      def initialize(template, config={}, app=Tap::App.current)
        super(config, app)
        @template = template
        @map = {}
        
        plength = placeholder.length
        template.each_with_index do |arg, index|
          if arg.index(placeholder) == 0
            @map[index] = arg[plength, arg.length - plength].to_i
          end
        end
      end
      
      def process(*args)
        result = template.dup
        
        @map.each_pair do |insert_idx, arg_idx|
          value = args[arg_idx]
          result[insert_idx] = value.nil? ? default : value
        end
        
        result
      end
      
      def to_spec
        spec = super
        spec['template'] = template
        spec
      end
    end 
  end
end