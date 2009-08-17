require 'tap/signals/class_methods'

module Tap
  module Signals
    def self.included(mod)
      mod.extend ClassMethods
      mod.instance_variable_set(:@signals, {})
      super
    end
    
    # To mount as a controller (provided in utils):
    #
    #   lambda do |env|
    #     obj.signal(env.path_info, env.query)
    #   end
    #
    # 
    # Should handle array args or hash.
    def signal(sig, args=[])
      if sig.nil?
        # make index, return
      end
      
      unless signal = self.class.signals[sig.to_sym]
        raise "unknown signal: #{sig} (#{self.class})"
      end
      
      if args.kind_of?(Hash)
        args = if signal.signature
          signal.signature.collect {|key| args[key] }
        else
          [args]
        end
      end
      
      signal.new(self).call(args)
    end
  end
end