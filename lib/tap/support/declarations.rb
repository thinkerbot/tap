module Tap
  module Support
    module Declarations
      def self.set_declaration_base(base)
        # TODO -- warn if base is Object -- conflict with Rake
        declaration_base = base.to_s
        declaration_base = "" if ["Object", "Tap"].include?(declaration_base)

        base.instance_variable_set(:@tap_declaration_base, declaration_base.underscore)
      end

      def self.included(base)
        set_declaration_base(base)
      end

      def self.extended(base)
        set_declaration_base(base)
      end
      
      def tasc(name, configs={}, options={}, &block)
        declare(Tap::Task, name, configs, options, &block)
      end

      def task(name, configs={}, options={}, &block)
        options[:arity] = arity(block) if block_given?
        tasc(name, configs, options, &task_block(block)).new
      end

      def file_tasc(name, configs={}, options={}, &block)
        declare(Tap::FileTask, name, configs, options, &block)
      end

      def file_task(name, configs={}, options={}, &block)
        options[:arity] = arity(block) if block_given?
        file_tasc(nest(name), configs, options, &task_block(block)).new
      end

      def worcflow(name, configs={}, options={}, &block)
        declare(Tap::Workflow, name, configs, options, &block)
      end

      def workflow(name, configs={}, options={}, &block)
        options[:arity] = arity(block) if block_given?
        worcflow(name, configs, options, &task_block(block)).new
      end

      protected

      def config(key, value=nil, options={}, &block)
        caller.each do |line|
          case line
          when Lazydoc::CALLER_REGEXP
            options[:desc] = Support::Lazydoc.register($1, $3.to_i - 1)
            break
          end
        end if options[:desc] == nil

        [:config, key, value, options, block]
      end

      def config_attr(key, value=nil, options={}, &block)
        caller.each do |line|
          case line
          when Lazydoc::CALLER_REGEXP
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
      
      def declare(klass, name, configs, options, &block)
        name, dependencies = case name
        when Hash then name.to_a[0]
        else [name, []]
        end
        
        dependencies = [dependencies] unless dependencies.kind_of?(Array)
        
        # Special case where configs is like [{:key => 'value'}]
        #if configs.kind_of?(Array) && configs.length == 1 && configs[0].kind_of?(Hash)
        #  configs = configs[0]
        #end
        
        klass.subclass(nest(name), configs, dependencies, options, &block)
      end

      def nest(name)
        # use self if self is a Module or Class, 
        # or self.class if self is an instance.
        File.join((self.kind_of?(Module) ? self : self.class).instance_variable_get(:@tap_declaration_base), name.to_s)
      end
      
      def arity(block)
        arity = block.arity
        
        case
        when arity > 0 then arity -= 1
        when arity < 0 then arity += 1
        end
        
        arity
      end

      def task_block(block)
        return nil if block == nil
        
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