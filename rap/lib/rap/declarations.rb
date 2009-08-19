require 'rap/task'

module Rap
  
  # Defines the Rap task declaration methods.  They may be included at the
  # top level (like Rake) or used through Rap.
  #
  # === Usage
  #
  # Unlike in rake, task will define actual task classes according to the task
  # names.  Task classes may be nested within modules using namespace.  It's
  # VERY important to realize this is the case both to aid in thing like
  # testing and to prevent namespace conflicts.  For example:
  #
  #   t = Rap.task(:sample)                  
  #   t.class                            # => Sample
  #
  #   Rap.namespace(:nested) do
  #     t = Rap.task(:sample)                
  #     t.class                          # => Nested::Sample
  #   end
  #
  # Normally all declared tasks are subclasses of Rap::Task, but
  # subclasses of Rap::Task can declare tasks as well.
  #
  #   class Alt < Rap::Task
  #   end
  #
  #   include Rap::Declarations
  #
  #   desc "task one, a subclass of Rap::Task"
  #   o = Rap.task(:one)
  #   o.class                            # => One
  #   o.class.superclass                 # => Rap::Task
  #   o.class.desc.to_s                  # => "task one, a subclass of Rap::Task"
  #
  #   namespace(:nest) do
  #     desc "task two, a nested subclass of Alt"
  #     t = Alt.task(:two)
  #     t.class                          # => Nest::Two
  #     t.class.superclass               # => Alt
  #     t.class.desc.to_s                # => "task two, a nested subclass of Alt"
  #   end
  #
  # This feature is only available to subclasses of Rap::Task and can
  # be very useful for creating inheritance hierarchies.  Note that other
  # declaration methods like 'desc' and 'namespace' are not available on
  # Rap::Task or subclasses, just 'task'.
  #
  # See the {Syntax Reference}[link:files/doc/Syntax%20Reference.html] for more
  # information.
  module Declarations
    # The environment in which declared task classes are registered.
    # By default Tap::Env.instance.
    def Declarations.env() @@env ||= Tap::Env.instance; end
    
    # Sets the declaration environment.
    def Declarations.env=(env) @@env=env; end
    
    # The declaration App (default Tap::App.instance)
    def Declarations.app() @@app ||= Tap::App.instance; end
    
    # Sets the declaration App.
    def Declarations.app=(app) @@app=app; end
    
    # The base constant for all task declarations, prepended to the task name.
    def Declarations.current_namespace() @@current_namespace; end
    @@current_namespace = ''
    
    # Tracks the current description, which will be used to
    # document the next task declaration.
    def Declarations.current_desc() @@current_desc; end
    @@current_desc = nil
    
    # Returns the instance of the task class in app.
    def Declarations.instance(tasc)
      tasc.instance(Declarations.app)
    end
    
    # Declares a task with a rake-like syntax.  Task generates a subclass of
    # Rap::Task, nested within the current namespace.
    def task(*args, &action)
      # resolve arguments and declare unknown dependencies
      name, configs, dependencies, arg_names = resolve_args(args) do |dependency| 
        register Rap::Task.subclass(dependency)
      end
      
      # generate the task class
      const_name = File.join(@@current_namespace, name.to_s).camelize
      tasc = declaration_class.subclass(const_name, configs, dependencies)
      
      # register documentation        
      desc = Lazydoc.register_caller(Description)
      desc.desc = @@current_desc
      @@current_desc = nil
      
      tasc.arg_names = arg_names
      tasc.desc = desc
      tasc.source_file = desc.document.source_file
      
      # add the action
      tasc.actions << action if action
      
      # register
      register tasc
      
      # return the instance
      instance = Declarations.instance(tasc)
      instance.config.bind(instance, true)
      instance
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
    
    # The class of task declared by task, by default Rap::Task. 
    # Used as a hook to set the declaring class in including modules 
    # (such as Rap::Task itself).
    def declaration_class
      Rap::Task
    end
    
    # Registers a task class with the Declarations.env, if necessary.
    # Returns task_class.
    def register(tasc)
      tasks = Declarations.env.manifest(:task)
      
      const_name = tasc.to_s
      constant = tasks.find do |const| 
        const.const_name == const_name
      end
      
      unless constant
        constant = Tap::Env::Constant.new(const_name)
        tasks.entries << constant
      end
      
      constant.comment = tasc.desc(false)
      tasc
    end
  end
  
  class Task
    class << self
      # :stopdoc:
      alias original_desc desc
      # :startdoc:
      
      include Declarations
      
      # :stopdoc:
      undef_method :desc
      alias desc original_desc
      
      # hide remaining Declarations methods (including Utils methods)
      private :namespace
      # :startdoc:
      
      private
      
      # overridden to provide self as the declaration_class
      def declaration_class # :nodoc:
        self
      end
    end
  end
  
  extend Declarations
end