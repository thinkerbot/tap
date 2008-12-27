autoload(:OpenStruct, 'ostruct')

module Tap
  module Declarations
    # Dependency tasks are a singleton version of tasks.  Dependency tasks only
    # have one instance (DependencyTask.instance) and the instance is
    # registered as a dependency, so it will only execute once.
    class DependencyTask < Tap::Task
      class << self
        attr_writer :blocks
        
        def blocks
          @blocks ||= []
        end
        
        attr_writer :arg_names
        
        def arg_names
          @arg_names ||= []
        end
        
        # Initializes instance and registers it as a dependency.
        def new(*args)
          @instance ||= super
          @instance.app.dependencies.register(@instance)
          @instance
        end
        
        def args
          args = Lazydoc::Arguments.new
          arg_names.each {|name| args.arguments << name.to_s }
          args
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
end