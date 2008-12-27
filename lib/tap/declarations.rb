require File.dirname(__FILE__) + "/../tap"
require "tap/declarations/declaration"
require "tap/declarations/dependency_task"

autoload(:OpenStruct, 'ostruct')

module Tap
  #--
  # more thought needs to go into extending Tap with Declarations
  # and there should be some discussion on why include works at
  # the top level (for main/Object) while extend should be used
  # in all other cases.
  module Declarations
    include Tap::Support::ShellUtils
    
    def self.extended(base) # :nodoc:
      declaration_base = base.to_s
      case declaration_base
      when "Object", "Tap", "main"
        declaration_base = ""
      end
      
      base.instance_variable_set(:@declaration_base, declaration_base.underscore)
      base.instance_variable_set(:@current_desc, nil)
    end
    
    # The Tap::Env for Dir.pwd
    def self.env
      @env ||= Tap::Env.instance_for(Dir.pwd)
    end
    
    # The declaration environment, by default Declarations.env
    def declaration_env
      @declaration_env ||= Declarations.env
    end
    
    attr_writer :declaration_base
    
    # The base constant for all task declarations, prepended to the task name.
    def declaration_base
      @declaration_base ||= ''
    end
    
    attr_writer :current_desc
    
    # Tracks the current description, which will be used to
    # document the next task declaration.
    def current_desc
      @current_desc ||= nil
    end
    
    # Declares a task with a rake-like syntax
    def task(*args, &block)
      task_name, configs, needs, arg_names = resolve_args(args)
      task_class = declare(task_name, configs, needs)
      
      # set the arg_names for the subclass
      task_class.arg_names = arg_names
      register_doc(task_class)
      
      # add the block to the task
      task_class.blocks << block if block
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
    
    # A helper to resolve the arguments for a task; returns the array
    # [task_name, configs, needs, arg_names].
    #
    # Adapted from Rake 0.8.3
    # Changes:
    # - no :needs support for the trailing Hash (which is now config)
    def resolve_args(args) # :nodoc:
      task_name = args.shift
      arg_names = args
      configs = {}
      needs = []
      
      # resolve hash task_names, for the syntax:
      #   task :name => [dependencies]
      if task_name.is_a?(Hash)
        hash = task_name
        case hash.length
        when 0 
          task_name = nil
        when 1 
          task_name = hash.keys[0]
          needs = hash[task_name]
        else
          raise ArgumentError, "multiple task names specified: #{hash.keys.inspect}"
        end
      end
      
      # ensure a task name is specified
      if task_name == nil
        raise ArgumentError, "no task name specified" if args.empty?
      end
      
      # pop off configurations, if present, using the syntax:
      #   task :name, :one, :two, {configs...}
      if arg_names.last.is_a?(Hash)
        configs = arg_names.pop
      end
      
      needs = needs.respond_to?(:to_ary) ? needs.to_ary : [needs]
      needs = needs.compact.collect do |need|
        
        unless need.kind_of?(Class)
          # lookup or declare non-class dependencies
          name = normalize_name(need).camelize
          need = Support::Constant.constantize(name) {|base, constants| declare(name) }
        end
        
        unless need.ancestors.include?(Tap::Task)
          raise ArgumentError, "not a task: #{need}"
        end
        
        need
      end
      
      [normalize_name(task_name), configs, needs, arg_names]
    end
    
    # helper to translate rake-style names to tap-style names, ie
    #
    #   normalize_name('nested:name')    # => "nested/name"
    #   normalize_name(:symbol)          # => "symbol"
    #
    def normalize_name(name) # :nodoc:
      name.to_s.tr(":", "/")
    end
    
    def declare(name, configs={}, dependencies=[])
      const_name = File.join(declaration_base, name).camelize
      
      # generate the subclass
      subclass = Support::Constant.constantize(const_name) do |base, constants|
        constants.each do |const|
          # nesting Tasks into Tasks is required for
          # namespaces with the same name as a task
          base = base.const_set(const, Class.new(DependencyTask))
        end
        base
      end
      
      unless subclass.ancestors.include?(DependencyTask)
        raise "not a DependencyTask: #{subclass}"
      end
      
      configs.each_pair do |key, value|
        subclass.send(:config, key, value, :desc => "")
      end
      
      dependencies.each do |dependency|
        dependency_name = File.basename(dependency.default_name)
        subclass.send(:depends_on, dependency_name, dependency)
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
    
    def register_doc(task_class)
      
      # register documentation
      caller[1] =~ Lazydoc::CALLER_REGEXP
      task_class.source_file = File.expand_path($1)
      manifest = task_class.lazydoc.register($3.to_i - 1, Declaration)
      manifest.desc = current_desc
      task_class.manifest = manifest
      
      self.current_desc = nil
      task_class
    end
  end
  
  extend Declarations
end