module Tap
  module Support
    module Declarations
      def tasc(name, *configs, &block)
        configs = configs[0] if configs.length == 1 && configs[0].kind_of?(Hash)
        Tap::Task.subclass(name, configs, &block)
      end
  
      def task(name, *configs, &block)
        tasc(name, *configs, &task_block(block)).new
      end
  
      def file_tasc(name, *configs, &block)
        configs = configs[0] if configs.length == 1 && configs[0].kind_of?(Hash)
        Tap::FileTask.subclass(name, configs, &block)
      end
  
      def file_task(name, *configs, &block)
        file_tasc(name, *configs, &task_block(block)).new
      end
  
      def worcflow(name, *configs, &block)
        configs = configs[0] if configs.length == 1 && configs[0].kind_of?(Hash)
        Tap::Workflow.subclass(name, configs, &block)
      end
  
      def workflow(name, *configs, &block)
        worcflow(name, *configs, &task_block(block)).new
      end
    
      protected
  
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
    
      private
    
      def task_block(block)
        lambda do |*inputs|
          inputs.unshift(self)
      
          arity = block.arity
          n = inputs.length
          unless n == arity || (arity < 0 && (-1-n) <= arity) 
            raise ArgumentError.new("wrong number of arguments (#{n} for #{arity})")
          end
      
          block.call(*inputs)
        end
      end
    end
  end
end