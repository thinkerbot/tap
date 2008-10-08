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
        
      register_doc(declare(name, configs, dependencies, &block), arg_names)
    end
    
    def task(*args, &block)
      name, configs, dependencies, arg_names = resolve_args(args)
      task_class = declare(name, configs, dependencies) do |*inputs|
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
      register_doc(task_class, arg_names)
      
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
      self.current_desc = Lazydoc::Comment.new
      current_desc.subject = str
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
 
        unless need.kind_of?(Class)
          # converts dependencies like 'update:session'
          # note this will prevent lookup from other envs.
          name = need.to_s.split(/:+/).join("/").camelize
          lookup, const = env.manifest(:tasks).find {|lookup, const| const.name == name }
          
          need = const ? const.constantize : declare(name)
        end
  
        unless need.ancestors.include?(Tap::Task)
          raise ArgumentError, "malformed dependency declaration: #{need}"
        end
        
        need
      end
      
      [task_name, configs, needs, arg_names]
    end
    
    def declare(name, configs={}, dependencies=[], &block)
      # nest the constant name
      name = File.join(declaration_base, name.to_s)
      
      # Generate the nesting constants as subclasses of Tap::Task
      # (this allows namespaces with the same name as a task)
      subclass, constants = name.to_s.constants_split
      constants.each {|const| subclass = subclass.const_set(const, Class.new(Tap::Task)) }

      # enhance the subclass
      configs.each_pair do |key, value|
        subclass.send(:config, key, value)
      end
      
      dependencies.each do |dependency|
        name = File.basename(dependency.default_name)
        subclass.send(:depends_on, name, dependency)
      end
      
      if block_given?
        subclass.send(:define_method, :process, &block)
      end
      
      # update any dependencies in instance
      subclass.dependencies.each do |dependency|
        subclass.instance.depends_on(dependency.instance)
      end
      
      # register the subclass in the manifest
      manifest = env.manifest(:tasks).build
      const_name = subclass.to_s
      
      unless manifest.entries.find {|lookup, const| const.name == const_name }
        manifest.entries << [const_name.underscore, Tap::Support::Constant.new(const_name)]
      end

      subclass
    end
    
    def register_doc(task_class, arg_names)
      
      # register documentation
      caller[1] =~ Lazydoc::CALLER_REGEXP
      task_class.source_file = File.expand_path($1)
      lazydoc = task_class.lazydoc(false)
      lazydoc[task_class.to_s]['manifest'] = current_desc || lazydoc.register($3.to_i - 1, Lazydoc::Declaration)
      
      if arg_names
        comment = Lazydoc::Comment.new
        comment.subject = arg_names.join(' ')
        lazydoc[task_class.to_s]['args'] = comment
      end
      
      self.current_desc = nil
      task_class
    end
  end
  
  extend Declarations
end