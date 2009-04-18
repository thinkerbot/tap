require 'rap/declaration_task'
require 'tap/support/shell_utils'

module Rap
  
  # Defines the rakish task declaration methods.  They may be included at the
  # top level (like Rake) or, since they included as a part of the API, used
  # through Rap.
  #
  # Unlike rake, task will define actual task classes according to the task
  # names.  Task classes may be nested within modules using namespace.  It's
  # VERY important to realize this is the case both to aid in thing like
  # testing and to prevent namespace conflicts.  For example:
  #
  #   Rap.task(:sample)              # => Sample.instance
  #   Rap.namespace(:nested) do
  #     Rap.task(:sample)            # => Nested::Sample.instance
  #   end
  #
  # Normally all declared tasks are subclasses of DeclarationTask.  An easy
  # way to use an existing subclasses of DeclarationTask as a base task is
  # to call declare on the subclass.  This feature is only available to
  # subclasses of DeclarationTask, but can be used within namespaces, and in
  # conjunction with desc.
  #
  #   class Alt < DeclarationTask
  #   end
  #
  #   include Rap::Declarations
  #
  #   desc "task one, a subclass of DeclarationTask"
  #   o = Rap.task(:one)
  #   o.class                          # => One
  #   o.class.superclass               # => DeclarationTask
  #   o.class.manifest.desc            # => "task one, a subclass of DeclarationTask"
  #
  #   namespace(:nest) do
  #
  #     desc "task two, a nested subclass of Alt"
  #     t = Alt.declare(:two)
  #     t.class                          # => Nest::Two
  #     t.class.superclass               # => Alt
  #     t.class.manifest.desc            # => "task two, a nested subclass of Alt"
  #   
  #   end
  #
  # See the {Syntax Reference}[link:files/doc/Syntax%20Reference.html] for usage.
  module Declarations
    include Tap::Support::ShellUtils
    
    # The environment in which declared task classes are registered.
    # By default the Tap::Env for Dir.pwd.
    def Declarations.env() @@env ||= Tap::Env.instance; end
    
    # Sets the declaration environment.
    def Declarations.env=(env) @@env=env; end
    
    def Declarations.app() @@app ||= Tap::App.instance; end
    
    def Declarations.app=(app) @@app=app; end
    
    # The base constant for all task declarations, prepended to the task name.
    def Declarations.current_namespace() @@current_namespace; end
    @@current_namespace = ''
    
    # Tracks the current description, which will be used to
    # document the next task declaration.
    def Declarations.current_desc() @@current_desc; end
    @@current_desc = nil
    
    def Declarations.instance(tasc)
      Declarations.app.class_dependency(tasc)
    end
    
    # Declares a task with a rake-like syntax.  Task generates a subclass of
    # DeclarationTask, nested within the current namespace.
    def task(*args, &action)
      # resolve arguments and declare unknown dependencies
      name, configs, dependencies, arg_names = resolve_args(args) do |dependency| 
        register DeclarationTask.subclass(dependency)
      end
      
      # generate the task class
      const_name = File.join(@@current_namespace, name.to_s).camelize
      task_class = declaration_class.subclass(const_name, configs, dependencies)
      register task_class
      
      # register documentation        
      manifest = Lazydoc.register_caller(Description)
      manifest.desc = @@current_desc
      @@current_desc = nil
      
      task_class.arg_names = arg_names
      task_class.manifest = manifest
      task_class.source_file = manifest.document.source_file
      
      # add the action
      task_class.actions << action if action
      
      # return the instance
      Declarations.app.class_dependency(task_class)
    end
    
    # Nests tasks within the named module for the duration of the block.
    # Namespaces may be nested.
    def namespace(name)
      previous_namespace = @@current_namespace
      @@current_namespace = File.join(previous_namespace, name.to_s.underscore)
      yield
      @@current_namespace = previous_namespace
    end
    
    # Sets the description for use by the next task declaration.
    def desc(str)
      @@current_desc = str
    end
    
    private
    
    # A helper to resolve the arguments for a task; returns the array
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
          need = Tap::Env::Constant.constantize(name) do |base, constants|
            const = block_given? ? yield(name) : nil
            const or raise ArgumentError, "unknown task class: #{name}"
          end
        end

        unless need.ancestors.include?(Tap::Task)
          raise ArgumentError, "not a task class: #{need}"
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
    def normalize_name(name)
      name.to_s.tr(":", "/")
    end
    
    # The class of task declared by task, by default DeclarationTask. 
    # Used as a hook to set the declaring class in including modules 
    # (such as DeclarationTask itself).
    def declaration_class
      DeclarationTask
    end
    
    # Registers a task class with the Declarations.env, if necessary.
    # Returns task_class.
    def register(task_class)
      tasks = Declarations.env.registered_objects(:task)
      const_name = task_class.to_s
      unless tasks.any? {|const| const.const_name == const_name }
        Declarations.env.register('task', Tap::Env::Constant.new(const_name))
      end
      
      task_class
    end
  end
  
  class DeclarationTask
    class << self
      include Declarations
      
      # alias task as declare, so that DeclarationTask and subclasses
      # may directly declare subclasses of themselves
      
      alias declare task
      private :task, :desc, :namespace
    end
  end
  
  extend Declarations
end