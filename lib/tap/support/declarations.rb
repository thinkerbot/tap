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
      
      def tasc(name, configs={}, &block)
        declare(Tap::Task, name, configs, &block)
      end

      def task(name, configs={}, &block)
         mod_declare(Tap::Task, name, configs, &block)
      end

      def file_tasc(name, configs={}, &block)
        declare(Tap::FileTask, name, configs, &block)
      end

      def file_task(name, configs={}, &block)
         mod_declare(Tap::FileTask, name, configs, &block)
      end
      
      protected

      def config(key, value=nil, options={}, &block)
        if options[:desc] == nil
          caller[0] =~ Lazydoc::CALLER_REGEXP
          options[:desc] = Support::Lazydoc.register($1, $3.to_i - 1)
        end 

        [:config, key, value, options, block]
      end

      def config_attr(key, value=nil, options={}, &block)
        if options[:desc] == nil
          caller[0] =~ Lazydoc::CALLER_REGEXP
          options[:desc] = Support::Lazydoc.register($1, $3.to_i - 1)
        end

        [:config_attr, key, value, options, block]
      end

      def c
        Support::Validation
      end

      private
      
      def arity(block)
        arity = block.arity
        
        case
        when arity > 0 then arity -= 1
        when arity < 0 then arity += 1
        end
        
        arity
      end
      
      def declare(klass, declaration, configs={}, options={}, &block)
        # Extract name and dependencies from declaration
        name, dependencies = case declaration
        when Hash then declaration.to_a[0]
        else [declaration, []]
        end
        
        unless dependencies.kind_of?(Array)
          dependencies = [dependencies]
        end
        
        unless dependencies.empty?
          dependencies.collect! do |dependency|
            case dependency
            when Array then dependency
            when String, Symbol then [dependency, declare(Tap::Task, dependency)]
            else 
              if dependency.kind_of?(Class) && dependency.ancestors.include?(Tap::Task)
                [File.basename(dependency.default_name), dependency]
              else
                raise ArgumentError, "malformed dependency declaration: #{dependency}"
              end
            end
          end
        end
        
        # Nest the constant name
        base = (self.kind_of?(Module) ? self : self.class).instance_variable_get(:@tap_declaration_base)
        name = File.join(base, name.to_s)
        
        klass.subclass(name, configs, dependencies, options, &block)
      end
      
      def mod_declare(klass, declaration, configs={}, &block)
        options = {}
        options[:arity] = arity(block) if block_given?

        subclass = declare(klass, declaration, configs, options)
        
        if block_given?
          mod = Module.new
          mod.module_eval %Q{
            ACTION = ObjectSpace._id2ref(#{block.object_id})
            def process(*args)
              results = super
              case ACTION.arity
              when 1 then ACTION.call(self)
              else ACTION.call(self, args)
              end
              results
            end
          }
          subclass.send(:include, mod)
        end
        subclass.instance
      end

    end
  end
end