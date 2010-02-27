module Tap
  module Signals
    class Configure < Signal
      def call(config)
        if config.kind_of?(Array)
          psr = ConfigParser.new(:add_defaults => false)
          psr.add(obj.class.configurations)
          args = psr.parse!(config)
          Utils.warn_ignored_args(args)
          
          config = psr.config
        end
        
        obj.reconfigure(config)
        obj.config
      end
    end
  end
end