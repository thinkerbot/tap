require 'ostruct'
require 'rap/utils'
require 'rap/description'

module Rap
  
  # Dependency tasks are a singleton version of tasks.  Dependency tasks only
  # have one instance (DeclarationTask.instance) and the instance is
  # registered as a dependency, so it will only execute once.
  class DeclarationTask < Tap::Task
    class << self
      attr_writer :blocks
      
      def blocks
        @blocks ||= []
      end
      
      attr_writer :arg_names
      
      def arg_names
        @arg_names ||= []
      end
      
      def args
        args = Lazydoc::Arguments.new
        arg_names.each {|name| args.arguments << name.to_s }
        args
      end
      
      # Initializes instance and registers it as a dependency.
      def new(*args)
        @instance ||= super
        @instance.app.dependencies.register(@instance)
        @instance
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
        subclass = Tap::Support::Constant.constantize(const_name) do |base, constants|
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
          subclass.send(:depends_on, dependency_name, dependency)
        end
        
        subclass
      end
      
      protected
      
      def declaration_class # :nodoc:
        self
      end
    end
    
    def process(*inputs)
      # collect inputs to make a rakish-args object
      args = {}
      self.class.arg_names.each do |arg_name|
        break if inputs.empty?
        args[arg_name] = inputs.shift
      end
      args = OpenStruct.new(args)
      
      # execute each block assciated with this task
      self.class.blocks.each do |task_block|
        case task_block.arity
        when 0 then task_block.call()
        when 1 then task_block.call(self)
        else task_block.call(self, args)
        end
      end
      
      nil
    end
  end
end