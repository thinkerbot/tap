require 'tap/task'
require 'tap/env'
require 'ostruct'
require 'rap/description'

module Rap
  
  # DeclarationTasks are a singleton version of tasks.  DeclarationTasks only
  # have one instance (DeclarationTask.instance) and the instance is
  # constructed so it will only execute once.
  class DeclarationTask < Tap::Task
    class << self
      attr_writer :actions
      
      # An array of actions (blocks) associated with this class.  Each of the
      # actions is called during process, with the instance and any args
      # passed to process organized into an OpenStruct.
      def actions
        @actions ||= []
      end
      
      attr_writer :arg_names
      
      # The argument names pulled from a task declaration.
      def arg_names
        @arg_names ||= []
      end
      
      # Returns a Lazydoc::Arguments constructed from arg_names.
      def args
        args = Lazydoc::Arguments.new
        arg_names.each {|name| args.arguments << name.to_s }
        args
      end
      
      # Looks up or creates the DeclarationTask subclass specified by name
      # (nested within declaration_base), and adds the configs and dependencies.
      # Declare also registers the subclass in the declaration_env tasks
      # manifest.
      # 
      # Configurations are always validated using the yaml transformation block
      # (see {Configurable::Validation.yaml}[http://tap.rubyforge.org/configurable/classes/Configurable/Validation.html]).
      #
      def subclass(const_name, configs={}, dependencies=[])
        # lookup or generate the subclass
        subclass = Tap::Env::Constant.constantize(const_name.to_s) do |base, constants|
          subclass_const = constants.pop
          constants.inject(base) do |namespace, const|
            # nesting Task classes into other Task classes is required
            # for namespaces with the same name as a task
            namespace.const_set(const, Class.new(DeclarationTask))
          end.const_set(subclass_const, Class.new(self))
        end

        # check a correct class was found
        unless subclass.ancestors.include?(self)
          raise "not a #{self}: #{subclass}"
        end

        # append configuration (note that specifying a desc 
        # prevents lazydoc registration of these lines)
        convert_to_yaml = Configurable::Validation.yaml
        configs.each_pair do |key, value|
          subclass.send(:config, key, value, :desc => "", &convert_to_yaml)
        end

        # add dependencies
        dependencies.each do |dependency|
          dependency_name = File.basename(dependency.default_name)
          
          # this suppresses 'method redefined' warnings
          if subclass.method_defined?(dependency_name)
            subclass.send(:undef_method, dependency_name)
          end
          
          subclass.send(:depends_on, dependency_name, dependency)
        end
        
        subclass
      end
    end
    
    # The result of self, set by call.
    attr_reader :result
    
    def initialize(config={}, name=nil, app=Tap::App.instance)
      super
      @resolved = false
      @result = nil
    end
    
    # Conditional call to the super call; only calls once.  Note that call
    # does not take any inputs, and neither should the super call.
    #
    # Returns result.
    def call(*args)
      unless @resolved
        @resolved = true
        @result = super
      end
      result
    end
    
    # Returns true if already resolved by call.
    def resolved?
      @resolved
    end
    
    # Resets self so call will call again.  Also sets result to nil.
    def reset
      @resolved = false
      @result = nil
    end
    
    # Collects the inputs into an OpenStruct according to the class arg_names,
    # and calls each class action in turn.  This behavior echoes the behavior
    # of Rake tasks.
    def process(*inputs)
      # collect inputs to make a rakish-args object
      args = {}
      self.class.arg_names.each do |arg_name|
        break if inputs.empty?
        args[arg_name] = inputs.shift
      end
      args = OpenStruct.new(args)
      
      # execute each block assciated with this task
      self.class.actions.each do |action|
        case action.arity
        when 0 then action.call()
        when 1 then action.call(self)
        else action.call(self, args)
        end
      end
      
      nil
    end
  end
end