require 'tap/utils'

module Tap
  # Signal attaches an object and allows a specific method to be triggered
  # through a standard interface.
  class Signal
    class << self
      # A description of self
      attr_accessor :desc
    end
  
    # The object receiving signals through self.
    attr_reader :obj
  
    # An optional block, used at the signal's discretion (normally passed to
    # the method the signal targets on obj).
    attr_reader :block
  
    def initialize(obj, &block)
      @obj = obj
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