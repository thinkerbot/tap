require 'rap/declaration_task'
require 'tap/support/shell_utils'

module Rap
  #--
  # more thought needs to go into extending Tap with Declarations
  # and there should be some discussion on why include works at
  # the top level (for main/Object) while extend should be used
  # in all other cases.
  module Declarations
    include Tap::Support::ShellUtils
    
    # The environment in which declared task classes are registered.
    # By default the Tap::Env for Dir.pwd.
    def Declarations.env() @@env ||= Tap::Env.instantiate(Dir.pwd); end
    
    # Sets the declaration environment.
    def Declarations.env=(env) @@env=env; end
    
    # The base constant for all task declarations, prepended to the task name.
    def Declarations.current_namespace() @@current_namespace; end
    @@current_namespace = ''
    
    # Tracks the current description, which will be used to
    # document the next task declaration.
    def Declarations.current_desc() @@current_desc; end
    @@current_desc = nil
    
    # Declares a task with a rake-like syntax
    def task(*args, &block)
      # resolve arguments and declare unknown dependencies
      task_name, configs, needs, arg_names = Utils.resolve_args(args) do |dependency| 
        DeclarationTask.declare(dependency)
      end
      
      # define the task class
      task_class = DeclarationTask.declare(task_name, configs, needs)
      task_class.arg_names = arg_names
      task_class.register_desc(@@current_desc, 2)
      task_class.blocks << block if block
      
      # cleanup
      @@current_desc = nil
      
      # return the instance
      task_class.instance
    end
    
    # Appends name to the declaration base for the duration of the block.
    # This has the effect of nesting any task declarations within the
    # Name module or class.
    def namespace(name, &block)
      previous_namespace = @@current_namespace
      @@current_namespace = File.join(previous_namespace, name.to_s.underscore)
      yield
      @@current_namespace = previous_namespace
    end
    
    # Sets the current description for use by the next task declaration.
    def desc(str)
      @@current_desc = str
    end
  end
  
  extend Declarations
end