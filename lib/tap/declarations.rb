require File.dirname(__FILE__) + "/../tap"
autoload(:OpenStruct, 'ostruct')

module Tap
  #--
  # more thought needs to go into extending Tap with Declarations
  # and there should be some discussion on why include works at
  # the top level (for main/Object) while extend should be used
  # in all other cases.
  module Declarations
    Lazydoc = Tap::Support::Lazydoc
    include Tap::Support::ShellUtils
    
    module Lazydoc
      class Declaration < Comment
        attr_accessor :desc
        
        def resolve(lines)
          super
          
          @subject = case
          when content.empty? || content[0][0].to_s !~ /^::desc(.*)/
            desc.to_s
          else
            content[0].shift
            $1.strip
          end
          
          self
        end
      end
    end
    
    module Rakish
      def new(*args)
        @instance ||= super
        @instance.app.dependencies.register(@instance)
        @instance
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
      @env ||= Tap::Env.instance_for(Dir.pwd)
    end
    
    def declaration_env
      @declaration_env ||= Declarations.env
    end
    
    attr_writer :declaration_base
    
    def declaration_base
      @declaration_base ||= ''
    end
    
    attr_writer :current_desc
    
    def current_desc
      @current_desc ||= nil
    end
    
    def task(*args, &block)
      const_name, configs, dependencies, arg_names = resolve_args(args)
      task_class = declare(const_name, configs, dependencies) do |*inputs|
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
      task_class.instance
    end
    
    def namespace(name, &block)
      current_base = declaration_base
      @declaration_base = File.join(current_base, name.to_s.underscore)
      yield
      @declaration_base = current_base
    end
    
    def desc(str)
      self.current_desc = str
    end
    
    protected
    
    # Resolve the arguments for a task/rule.  Returns an array of
    # [task_name, configs, needs, arg_names].
    #
    # Adapted from Rake 0.8.3
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
          name = normalize_name(need).camelize
          need = Support::Constant.constantize(name) do |base, constants|
            declare(name)
          end
        end
  
        unless need.ancestors.include?(Tap::Task)
          raise ArgumentError, "not a task: #{need}"
        end
        
        need
      end
      
      [normalize_name(task_name), configs, needs, arg_names]
    end
    
    def normalize_name(name)
      name.to_s.underscore.tr(":", "/")
    end
    
    def declare(name, configs={}, dependencies=[], &block)
      const_name = File.join(declaration_base, name).camelize
      
      # generate the subclass
      subclass = Support::Constant.constantize(const_name) do |base, constants|
        constants.each do |const|
          # nesting Tasks into Tasks is required for
          # namespaces with the same name as a task
          base = base.const_set(const, Class.new(Tap::Task))
        end
        base
      end

      subclass.extend Rakish
      
      configs.each_pair do |key, value|
        subclass.send(:config, key, value)
      end
      
      dependencies.each do |dependency|
        dependency_name = File.basename(dependency.default_name)
        subclass.send(:depends_on, dependency_name, dependency)
      end
      
      if block_given?
        subclass.send(:undef_method, :process) if subclass.method_defined?(:process)
        subclass.send(:define_method, :process, &block)
      end
      
      # update any dependencies in instance
      subclass.dependencies.each do |dependency|
        subclass.instance.depends_on(dependency.instance)
      end
      
      # register the subclass in the manifest
      manifest = declaration_env.tasks
      const_name = subclass.to_s
      unless manifest.entries.any? {|const| const.name == const_name }
        manifest.entries << Tap::Support::Constant.new(const_name)
      end
      
      subclass
    end
    
    def register_doc(task_class, arg_names)
      
      # register documentation
      caller[1] =~ Lazydoc::CALLER_REGEXP
      task_class.source_file = File.expand_path($1)
      manifest = task_class.lazydoc(false).register($3.to_i - 1, Lazydoc::Declaration)
      manifest.desc = current_desc
      task_class.manifest = manifest
      
      self.current_desc = nil
      
      if arg_names
        comment = Lazydoc::Comment.new
        comment.subject = arg_names.collect {|name| name.to_s.upcase }.join(' ')
        task_class.args = comment
      end

      task_class
    end
  end
  
  extend Declarations
end