require 'tap/task'

module Tap
  module Tasks
    # ::task signal via a task
    class Signal < Tap::Task
      class << self
        def build(spec={}, app=Tap::App.current)
          new(spec['sig'], spec['config'], app)
        end
        
        def convert_to_spec(parser, args)
          if args.empty?
            raise "no signal specified"
          end
          
          {
            'config' => parser.nested_config,
            'sig'  => args.shift
          }
        end
      end
      
      attr_accessor :sig
      
      def initialize(sig, config={}, app=Tap::App.current)
        super(config, app)
        @sig = sig
      end
      
      def process(*args)
        app.signal(sig).call(args)
      end
      
      def to_spec
        spec = super
        spec['sig'] = sig
        spec
      end
    end
  end
end