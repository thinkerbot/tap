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
        subclass = declare(Tap::Task, name, configs)
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
        subclass.instance
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
      
      def declare(klass, declaration, configs={}, &block)
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
            when String, Symbol
              declare(Tap::Task, dependency)
            else dependency
            end
          end
        end
        
        # Nest the constant name
        base = (self.kind_of?(Module) ? self : self.class).instance_variable_get(:@tap_declaration_base)
        name = File.join(base, name.to_s)
        
        klass.subclass(name, configs, dependencies, &block)
      end
    end
  end
end