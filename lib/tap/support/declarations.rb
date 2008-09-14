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
      
      def parse(declaration)
        # Extract name and dependencies from declaration
        name, dependencies = case declaration
        when Hash then declaration.to_a[0]
        else [declaration, []]
        end
        
        unless dependencies.kind_of?(Array)
          raise ArgumentError, "dependencies should be specified as an array (was #{dependencies.class})"
        end
        
        unless dependencies.empty?
          dependencies.collect! do |entry|
            dependency, argv = case entry
            when Array then entry
            else [entry, []]
            end
            
            unless dependency.kind_of?(Class)
              dependency = declare(Tap::Task, dependency)
            end
      
            if dependency.ancestors.include?(Tap::Task)
              [File.basename(dependency.default_name), dependency, argv]
            else
              raise ArgumentError, "malformed dependency declaration: #{dependency}"
            end
          end
        end
        
        [name, dependencies]
      end
      
      def declare(klass, declaration, configs={}, options={}, &block)
        # parse the declaration
        name, dependencies = parse(declaration)
        
        # nest the constant name
        base = (self.kind_of?(Module) ? self : self.class).instance_variable_get(:@tap_declaration_base)
        name = File.join(base, name.to_s)
        
        # generate the subclass
        subclass = klass.subclass(name, configs, dependencies, options, &block)
        
        # register documentation
        caller[1] =~ Support::Lazydoc::CALLER_REGEXP
        subclass.source_file = File.expand_path($1)
        lazydoc = subclass.lazydoc(false)
        lazydoc[subclass.to_s]['manifest'] = lazydoc.register($3.to_i - 1).extend DeclarationManifest      

        arity = options[:arity] || (block_given? ? block.arity : -1)
        comment = Comment.new
        comment.subject = case
        when arity > 0
          Array.new(arity, "INPUT").join(' ')
        when arity < 0
          array = Array.new(-1 * arity - 1, "INPUT")
          array << "INPUTS..."
          array.join(' ')
        else ""
        end
        lazydoc[subclass.to_s]['args'] ||= comment
        
        subclass
      end
      
      module DeclarationManifest
        
      end
    end
  end
end