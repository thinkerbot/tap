require File.dirname(__FILE__)

module Tap
  module Declarations
    def tasc(name, *configs, &block)
      configs = configs[0] if configs.length == 1 && configs[0].kind_of?(Hash)
      Tap::Task.subclass(name, configs, &block)
    end
    
    def file_tasc(name, *configs, &block)
      configs = configs[0] if configs.length == 1 && configs[0].kind_of?(Hash)
      Tap::FileTask.subclass(name, configs, &block)
    end
    
    def worcflow(name, *configs, &block)
      configs = configs[0] if configs.length == 1 && configs[0].kind_of?(Hash)
      Tap::Workflow.subclass(name, configs, &block)
    end
    
    def config(key, value=nil, options={}, &block)
      caller.each_with_index do |line, index|
        case line
        when /^(([A-z]:)?[^:]+):(\d+)/
          options[:desc] = Support::Lazydoc.register($1, $3.to_i - 1)
          break
        end
      end if options[:desc] == nil
      
      [:config, key, value, options, block]
    end
    
    def config_attr(key, value=nil, options={}, &block)
      caller.each_with_index do |line, index|
        case line
        when /^(([A-z]:)?[^:]+):(\d+)/
          options[:desc] = Support::Lazydoc.register($1, $3.to_i - 1)
          break
        end
      end if options[:desc] == nil
      
      [:config_attr, key, value, options, block]
    end
    
    def c
      Support::Validation
    end
  end
end