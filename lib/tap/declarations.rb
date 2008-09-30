require "#{File.dirname(__FILE__)}/../tap"
autoload(:OpenStruct, 'ostruct')

module Tap
  module Declarations
    Lazydoc = Tap::Support::Lazydoc
    
    module Lazydoc
      class Declaration < Comment
        def resolve(lines)
          super
          
          @subject = case
          when content.empty? || content[0][0].to_s !~ /^::desc(.*)/ then ""
          else
            content[0].shift
            $1.strip
          end
          
          self
        end
      end
    end
    
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
    
    def tasc(*args, &block)
      # in this scheme, arg_names will be empty
      name, configs, dependencies, arg_names = resolve_args(args)
      declare(Tap::Task, name, configs, dependencies, arg_names, &block)
    end
    
    def task(*args, &block)
      name, configs, dependencies, arg_names = resolve_args(args)
      
      task_class = declare(Tap::Task, name, configs, dependencies, arg_names) do |*inputs|
        args = {}
        arg_names.each do |arg_name|
          break if inputs.empty?
          args[arg_name] = inputs.shift
        end
        
        args = OpenStruct.new(args)
        self.class::BLOCKS.each do |task_block|
          case task_block.arity
          when 0 then task_block.call()
          when 1 then task_block.call(self)
          else task_block.call(self, args)
          end
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
        options[:desc] = Lazydoc.register($1, $3.to_i - 1)
      end 

      [:config, key, value, options, block]
    end

    def config_attr(key, value=nil, options={}, &block)
      if options[:desc] == nil
        caller[0] =~ Lazydoc::CALLER_REGEXP
        options[:desc] = Lazydoc.register($1, $3.to_i - 1)
      end

      [:config_attr, key, value, options, block]
    end

    def c
      Tap::Support::Validation
    end

    private
    
    # Resolve the arguments for a task/rule.  Returns a triplet of
    # [task_name, configs, prerequisites, arg_name_list].
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
      
      [task_name, configs, needs, arg_names]
    end

    def arity(block)
      arity = block.arity
      
      case
      when arity > 0 then arity -= 1
      when arity < 0 then arity += 1
      end
      
      arity
    end
    
    def declare(klass, name, configs={}, dependencies=[], arg_names=[], &block)
      # nest the constant name
      base = (self.kind_of?(Module) ? self : self.class).instance_variable_get(:@tap_declaration_base)
      name = File.join(base, name.to_s)
      
      # generate the subclass
      subclass = klass.subclass(name, configs, dependencies, &block)
      
      # register documentation
      caller[1] =~ Lazydoc::CALLER_REGEXP
      subclass.source_file = File.expand_path($1)
      lazydoc = subclass.lazydoc(false)
      lazydoc[subclass.to_s]['manifest'] = lazydoc.register($3.to_i - 1, Lazydoc::Declaration)

      if arg_names.empty?
        arity = block_given? ? arity(block) : -1
        case 
        when arity > 0
          arg_names = Array.new(arity, "INPUT")
        when arity < 0
          arg_names = Array.new(-1 * arity - 1, "INPUT")
          arg_names << "INPUTS..."
        end
      end
      
      comment = Lazydoc::Comment.new
      comment.subject = arg_names.join(' ')
      lazydoc[subclass.to_s]['args'] = comment
      
      # update any dependencies in instance
      subclass.dependencies.each do |dependency, args|
        subclass.instance.depends_on(dependency.instance, *args)
      end
      
      dir = File.dirname(lazydoc.source_file)
      manifest = Tap::Env.instance_for(dir).manifest(:tasks).build
      const_name = subclass.to_s
      unless manifest.entries.find {|lookup, const| const.name == const_name }
        manifest.entries << [const_name.underscore, Tap::Support::Constant.new(const_name, lazydoc.source_file)]
      end
      
      subclass
    end
  end
  
  extend Declarations
end