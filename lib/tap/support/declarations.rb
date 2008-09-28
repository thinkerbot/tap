require 'tap/support/lazydoc/declaration'
autoload(:OpenStruct, 'ostruct')

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
        # in this scheme, arg_names will be empty
        name, arg_names, configs, dependencies = resolve_args([name, configs])
        declare(Tap::Task, name, configs, dependencies, &block)
      end
      
      def task(*args, &block)
        name, arg_names, configs, dependencies = resolve_args(args)
        
        task_class = declare(Tap::Task, name, configs, dependencies) do |*inputs|
          args = OpenStruct.new
          arg_names.each do |arg_name|
            break if inputs.empty?
            args.arg_name = inputs.shift
          end

          self.class::BLOCKS.each do |task_block|
            task_block.call(self, args)
          end
        end
        
        unless task_class.const_defined?(:BLOCKS)
          task_class.const_set(:BLOCKS, [])
        end
        task_class::BLOCKS << block unless block == nil
        task_class.instance
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
      
      # Resolve the arguments for a task/rule.  Returns a triplet of
      # [task_name, arg_name_list, configs, prerequisites].
      #
      # From Rake 0.8.3
      # Changes:
      # - no :needs support for the trailing Hash (which is now config)
      def resolve_args(args)
        task_name = args.shift
        arg_names = args
        configs = {}
        needs = []
        
        if task_name.is_a?(Hash)
          hash = task_name
          task_name = hash.keys[0]
          needs = hash[task_name]
        end
        
        if arg_names.last.is_a?(Hash)
          configs = arg_names.pop
        end
        
        needs = needs.respond_to?(:to_ary) ? needs.to_ary : [needs]
        needs = needs.compact.collect do |need|
          dependency, argv = case need
          when Array then need
          else [need, []]
          end
          
          unless dependency.kind_of?(Class)
            dependency = declare(Tap::Task, dependency)
          end
    
          if dependency.ancestors.include?(Tap::Task)
            [File.basename(dependency.default_name), dependency, argv]
          else
            raise ArgumentError, "malformed dependency declaration: #{need}"
          end
        end
        
        [task_name, arg_names, configs, needs]
      end

      def arity(block)
        arity = block.arity
        
        case
        when arity > 0 then arity -= 1
        when arity < 0 then arity += 1
        end
        
        arity
      end
      
      def declare(klass, name, configs={}, dependencies=[], options={}, &block)
        # nest the constant name
        base = (self.kind_of?(Module) ? self : self.class).instance_variable_get(:@tap_declaration_base)
        name = File.join(base, name.to_s)
        
        # generate the subclass
        subclass = klass.subclass(name, configs, dependencies, options, &block)
        
        # register documentation
        caller[1] =~ Lazydoc::CALLER_REGEXP
        subclass.source_file = File.expand_path($1)
        lazydoc = subclass.lazydoc(false)
        lazydoc[subclass.to_s]['manifest'] = lazydoc.register($3.to_i - 1, Lazydoc::Declaration)

        arity = options[:arity] || (block_given? ? block.arity : -1)
        comment = Lazydoc::Comment.new
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
      
    end
  end
end