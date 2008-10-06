require File.dirname(__FILE__) + "/../tap"
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
    
    module TaskSubclass
      def set(name, configs, dependencies, &block)
        # set default name
        self.default_name = name.underscore
        
        # enhance configurations
        case configs
        when Hash
          # hash configs are simply added as default configurations
          configs.keys.each do |key|
            undef_method(key) if method_defined?(key)
            undef_method("#{key}=") if method_defined?("#{key}=")
          end

          attr_accessor(*configs.keys)
          configs.each_pair do |key, value|
            configurations.add(key, value)
          end
          public(*configs.keys)
        when Array
          # array configs define configuration methods
          configs.each do |method, key, value, opts, config_block| 
            send(method, key, value, opts, &config_block)
          end
        else 
          raise ArgumentError, "cannot define configurations from: #{configs}"
        end
        
        # enhance dependencies
        dependencies.each do |name, dependency_class, args|
          dependency(name, dependency_class, *(args ? args : []))
        end
        
        # define process method
        if block
          undef_method(:process) if method_defined?(:process)
          define_method(:process, &block)
        end
      end
    end
    
    module TaskSingleton
      def new(*args)
        @instance ||= super
      end
    end
    
    def self.extended(base)
      declaration_base = base.to_s
      case declaration_base
      when "Object", "Tap", "main"
        declaration_base = ""
      end
      
      base.instance_variable_set(:@declaration_base, declaration_base.underscore)
      base.instance_variable_set(:@current_desc, nil)
    end
    
    def self.env
      @env ||= Tap::Env.new(:load_paths => [], :command_paths => [], :generator_paths => [])
    end
    
    def env
      @env ||= Declarations.env
    end
    
    attr_accessor :declaration_base
    
    attr_accessor :current_desc
    
    def tasc(*args, &block)
      name, configs, dependencies, arg_names = resolve_args(args)
      
      # do a little dance to anticipate
      # arg_names if none are provided
      if arg_names.empty?
        if block_given?
          arity = block.arity
          case 
          when arity > 0
            arg_names = Array.new(arity, "INPUT")
          when arity < 0
            arg_names = Array.new(-1 * arity - 1, "INPUT")
            arg_names << "INPUTS..."
          end
        else
          # indicates no block was provided,
          # no args comment is set.
          arg_names = nil
        end
      end
        
      declare(name, configs, dependencies, arg_names, &block)
    end
    
    def task(*args, &block)
      name, configs, dependencies, arg_names = resolve_args(args)
      task_class = declare(name, configs, dependencies, arg_names) do |*inputs|
        # collect inputs to make a rakish-args object
        args = {}
        arg_names.each do |arg_name|
          break if inputs.empty?
          args[arg_name] = inputs.shift
        end
        args = OpenStruct.new(args)
        
        # execute each block assciated with this task
        self.class::BLOCKS.each do |task_block|
          case task_block.arity
          when 0 then task_block.call()
          when 1 then task_block.call(self)
          else task_block.call(self, args)
          end
        end
        
        nil
      end
      
      # add the block to the task
      unless task_class.const_defined?(:BLOCKS)
        task_class.const_set(:BLOCKS, [])
      end
      task_class::BLOCKS << block unless block == nil
      
      # ensure the task has only one instance
      task_class.extend TaskSingleton
      task_class.instance
    end
    
    def namespace(name, &block)
      current_base = declaration_base
      @declaration_base = File.join(current_base, name.to_s.underscore)
      yield
      @declaration_base = current_base
    end
    
    def desc(str)
      @current_desc = Lazydoc::Comment.new
      @current_desc.subject = str
    end
    
    protected
    
    # Resolve the arguments for a task/rule.  Returns a triplet of
    # [task_name, configs, prerequisites, arg_name_list, ].
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
          # converts dependencies like 'update:session'
          # note this will prevent lookup from other envs.
          dependency = dependency.to_s.split(/:+/).join("/").camelize
          lookup, const = env.manifest(:tasks).find {|lookup, const| const.name == dependency }
          dependency = const ? const.constantize : without_desc { declare(dependency) }
        end
  
        if dependency.ancestors.include?(Tap::Task)
          [File.basename(dependency.default_name), dependency, argv]
        else
          raise ArgumentError, "malformed dependency declaration: #{need}"
        end
      end
      
      [task_name, configs, needs, arg_names]
    end
    
    def without_desc
      desc = @current_desc
      @current_desc = nil
      result = yield
      
      @current_desc = desc
      result
    end
    
    def declare(name, configs={}, dependencies=[], arg_names=[], &block)
      # nest the constant name
      name = File.join(declaration_base, name.to_s)
      
      # Generate the nesting constants as subclasses of Tap::Task
      # (this allows namespaces with the same name as a task)
      subclass, constants = name.to_s.constants_split
      constants.each {|const| subclass = subclass.const_set(const, Class.new(Tap::Task))}
      
      subclass.extend TaskSubclass
      subclass.set(subclass.to_s, configs, dependencies, &block)
      
      # register documentation
      caller[1] =~ Lazydoc::CALLER_REGEXP
      subclass.source_file = File.expand_path($1)
      lazydoc = subclass.lazydoc(false)
      lazydoc[subclass.to_s]['manifest'] = current_desc || lazydoc.register($3.to_i - 1, Lazydoc::Declaration)
      
      if arg_names
        comment = Lazydoc::Comment.new
        comment.subject = arg_names.join(' ')
        lazydoc[subclass.to_s]['args'] = comment
      end
      
      # update any dependencies in instance
      subclass.dependencies.each do |dependency, args|
        subclass.instance.depends_on(dependency.instance, *args)
      end
      
      if current_desc
        manifest = env.manifest(:tasks).build
        const_name = subclass.to_s
        
        unless manifest.entries.find {|lookup, const| const.name == const_name }
          manifest.entries << [const_name.underscore, Tap::Support::Constant.new(const_name, lazydoc.source_file)]
        end
        
        @current_desc = nil
      end
      
      subclass
    end
  end
  
  extend Declarations
end