require 'tap/task'
require 'tap/declarations/context'
require 'tap/declarations/description'

module Tap
  module Declarations
    
    # Returns the context app.
    def app
      context.app
    end
    
    # Declares a task with a rake-like syntax.  Task generates a subclass of
    # Tap::Task, nested within the current namespace.
    def task(name, configs={}, &block)
      # generate the task class (note that nesting Task classes into other
      # Task classes is required for namespaces with the same name as a task)
      const_name = File.join(context.namespace, name.to_s).camelize
      tasc = declaration_class.subclass(const_name, configs, &block)
      register tasc
      
      # register documentation
      desc = Lazydoc.register_caller(Description)
      desc.desc = context.desc
      context.desc = nil
      
      tasc.desc = desc
      tasc
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
    
    # The declarations context.
    def context
      @context ||= Context.instance
    end
    
    # The class of task declared by task, by default Tap::Task. 
    # Used as a hook to set the declaring class in including modules 
    # (such as Tap::Task itself).
    def declaration_class
      Tap::Task
    end
    
    # Registers a task class with the Declarations.app.env, if necessary.
    # Returns task_class.
    def register(tasc)
      constant = app.env.set(tasc, nil)
      constant.register_as('declaration', tasc.desc.to_s)
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
      private :namespace, :app
      # :startdoc:
      
      def subclass(const_name, configs={})
        subclass = Env::Constant.constantize(const_name) do |base, constants|
          subclass_const = constants.pop
          constants.inject(base) do |namespace, const|
            namespace.const_set(const, Class.new(Tap::Task))
          end.const_set(subclass_const, Class.new(self))
        end

        # check a correct class was found
        unless subclass.ancestors.include?(self)
          raise "not a #{self}: #{subclass}"
        end

        # append configuration (note that specifying a desc prevents lazydoc
        # registration of these lines)
        convert_to_yaml = Configurable::Validation.yaml
        configs.each_pair {|key, value| subclass.send(:config, key, value, :desc => "", &convert_to_yaml) }

        if block_given?
          # prevents assessment of process args by lazydoc
          subclass.const_attrs[:process] = '*args'
          subclass.send(:define_method, :process) {|*args| yield(self, args) }
        end
        
        subclass
      end
      
      private
      
      # overridden to provide self as the declaration_class
      def declaration_class # :nodoc:
        self
      end
    end
  end
  
  extend Declarations
end