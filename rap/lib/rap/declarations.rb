require 'rap/declarations/context'

module Rap
  
  # Defines the Rap task declaration methods.  They may be included at the top
  # level (like Rake) or used through Rap.
  #
  # === Usage
  #
  # Unlike in rake, task will define actual task classes according to the task
  # names.  Task classes may be nested within modules using namespace.  For
  # example:
  #
  #   t = Rap.task(:sample)                  
  #   t.class                            # => Sample
  #
  #   Rap.namespace(:nested) do
  #     t = Rap.task(:sample)                
  #     t.class                          # => Nested::Sample
  #   end
  #
  # Normally all declared tasks are subclasses of Rap::Task, but subclasses of
  # Rap::Task can declare tasks as well.
  #
  #   class Subclass < Rap::Task
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
  #     desc "task two, a nested subclass of Subclass"
  #     t = Subclass.task(:two)
  #     t.class                          # => Nest::Two
  #     t.class.superclass               # => Subclass
  #     t.class.desc.to_s                # => "task two, a nested subclass of Subclass"
  #   end
  #
  # This feature is only available to subclasses of Rap::Task and can be very
  # useful for creating inheritance hierarchies.  Note that other declaration
  # methods like 'desc' and 'namespace' are not available on Rap::Task or
  # subclasses, just 'task'.
  #
  # See the {Syntax Reference}[link:files/doc/Syntax%20Reference.html] for
  # more information.
  module Declarations
    
    # Returns the context app.
    def app
      context.app
    end
    
    # Returns the instance for the class, registered to app.
    def instance(klass)
      klass.instance(app)
    end
    
    # Declares a task with a rake-like syntax.  Task generates a subclass of
    # Rap::Task, nested within the current namespace.
    def task(*args, &action)
      # resolve arguments and declare unknown dependencies
      name, configs, dependencies, arg_names = resolve_args(args) do |dependency| 
        register Rap::Task.subclass(dependency)
      end
      
      # generate the task class
      const_name = File.join(context.namespace, name.to_s).camelize
      tasc = declaration_class.subclass(const_name, configs, dependencies)
      register tasc
      
      # register documentation
      desc = Lazydoc.register_caller(Description)
      desc.desc = context.desc
      context.desc = nil
      
      tasc.arg_names = arg_names
      tasc.desc = desc
      
      # add the action
      tasc.actions << action if action
      
      # return the instance
      instance = tasc.instance(app)
      instance.config.import(configs)
      instance
    end
    
    # Nests tasks within the named module for the duration of the block.
    # Namespaces may be nested.
    def namespace(name)
      previous_namespace = context.namespace
      context.namespace = File.join(previous_namespace, name.to_s.underscore)
      yield
      context.namespace = previous_namespace
    end
    
    # Sets the description for use by the next task declaration.
    def desc(str)
      context.desc = str
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
    
    # The declarations context.
    def context
      @context ||= Context.instance
    end
    
    # The class of task declared by task, by default Rap::Task. 
    # Used as a hook to set the declaring class in including modules 
    # (such as Rap::Task itself).
    def declaration_class
      Rap::Task
    end
    
    # Registers a task class with the Declarations.app.env, if necessary.
    # Returns task_class.
    def register(tasc)
      app.env.register(tasc)
      tasc
    end
  end
  
  class Task
    class << self
      # :stopdoc:
      alias original_desc desc
      alias original_instance instance
      # :startdoc:
      
      include Declarations
      
      # :stopdoc:
      undef_method :desc
      alias desc original_desc
      
      undef_method :instance
      alias instance original_instance
      
      # hide remaining Declarations methods (including Utils methods)
      private :namespace, :app
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