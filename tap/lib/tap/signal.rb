require 'tap/utils'

module Tap
  # Signal attaches an object and allows a specific method to be triggered
  # through a standard interface.
  class Signal
    class << self
      # A description of self
      attr_accessor :desc
      
      def parse(argv=ARGV, app=Tap::App.instance, &block)
        parse!(argv.dup, app, &block)
      end
      
      def parse!(argv=ARGV, app=Tap::App.instance)
        sig, *args = argv
        obj = app.signal(sig)
        yield(obj, args) if block_given?
        obj
      end
      
      def build(spec={}, app=Tap::App.instance)
        app.route(spec['obj'], spec['sig'])
      end
    end
  
    # The object receiving signals through self.
    attr_reader :obj
  
    # The app for self
    attr_reader :app
  
    # An optional block, used at the signal's discretion (normally passed to
    # the method the signal targets on obj).
    attr_reader :block
  
    def initialize(obj, app=Tap::App.instance, &block)
      @obj = obj
      @app = app
      @block = block
    end
  
    # Calls process with the input args and returns the result.
    def call(args)
      process(args)
    end
  
    # Simply returns the input args.
    def process(args)
      args
    end
  
    def associations
      [[obj]]
    end
  
    def to_spec
      {
        'obj' => app.var(obj),
        'sig' => obj.sig(self)
      }
    end
    
    def inspect
      "#<#{self.class}:#{object_id}>"
    end
    
    protected
  
    def convert_to_array(obj, signature=[], options=false)
      return obj if obj.kind_of?(Array)
    
      argv = signature.collect {|key| obj[key] }
    
      if options
        opts = {}
        (obj.keys - signature).each do |key|
          opts[key] = obj[key]
        end
      
        argv << opts
      end
    
      argv
    end
  
    def convert_to_hash(obj, signature=[], remainder=nil)
      return obj if obj.kind_of?(Hash)
    
      args, argh = obj, {}
      signature.each do |key|
        argh[key] = args.shift
      end
    
      if remainder
        argh[remainder] = args
      end
    
      argh
    end
  end
end