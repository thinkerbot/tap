module Tap
  # = Overview
  #
  # Tasks are the basic organizational unit of Tap.  Tasks provide
  # a standard backbone for creating the working parts of an application
  # by facilitating configuration, batched execution of methods, and 
  # interaction with the command line.
  #
  # The functionality of Task is built from several base modules:
  # - Tap::Support::Batchable
  # - Tap::Support::Configurable
  # - Tap::Support::Executable
  #
  # Tap::Workflow is built on the same foundations; the sectons on
  # configuration and batching apply equally to Workflows as Tasks.
  #
  # === Task Definition
  #
  # Tasks are instantiated with a task block; when the task is run
  # the block gets called with the enqued inputs.  As such, the block
  # should specify the same number of inputs as you enque (plus the
  # task itself, which is a standard input).
  #
  #   no_inputs = Task.new {|task| }
  #   one_input = Task.new {|task, input| }
  #   mixed_inputs = Task.new {|task, a, b, *args| }
  #
  #   no_inputs.enq
  #   one_input.enq(:a)
  #   mixed_inputs.enq(:a, :b)
  #   mixed_inputs.enq(:a, :b, 1, 2, 3)
  #
  # Subclasses of Task specify executable code by overridding the process 
  # method. In this case the number of enqued inputs should correspond to
  # process (passing the task would be redundant).
  #
  #   class NoInput < Tap::Task
  #     def process() end
  #   end
  #
  #   class OneInput < Tap::Task
  #     def process(input) end
  #   end
  #
  #   class MixedInputs < Tap::Task
  #     def process(a, b, *args) end
  #   end
  #
  #   NoInput.new.enq
  #   OneInput.new.enq(:a)
  #   MixedInputs.new.enq(:a, :b)
  #   MixedInputs.new.enq(:a, :b, 1, 2, 3)
  #
  # === Configuration 
  #
  # Tasks are configurable.  By default each task will be configured
  # with the default class configurations, which can be set when the 
  # class is defined. 
  #
  #   class ConfiguredTask < Tap::Task
  #     config :one, 'one'
  #     config :two, 'two'
  #   end
  # 
  #   t = ConfiguredTask.new
  #   t.name                 # => "configured_task"
  #   t.config               # => {:one => 'one', :two => 'two'}
  #
  # Configurations can be validated or processed using an optional
  # block.  Tap::Support::Validation pre-packages several common
  # validation/processing blocks, and can be accessed through the
  # class method 'c':
  #
  #   class ValidatingTask < Tap::Task
  #     # string config validated to be a string
  #     config :string, 'str', &c.check(String)
  #
  #     # integer config; string inputs are converted using YAML
  #     config :integer, 1, &c.yaml(Integer)
  #   end 
  #
  #   t = ValidatingTask.new
  #   t.string = 1           # => ValidationError
  #   t.integer = 1.1        # => ValidationError
  #
  #   t.integer = "1"
  #   t.integer == 1         # => true 
  #
  # Tasks have a name that gets used as a relative filepath to find
  # associated files (for instance config_file). By default the task 
  # name is based on the task class, such that Tap::Task corresponds
  # to 'tap/task'.  Custom names can be provided when a task is 
  # initialized, as can additional and/or overriding configurations.
  #
  #   # [/path/to/app/config/example.yml]
  #   # one: ONE
  #  
  #   t = ConfiguredTask.new "example", :three => 'three'
  #   t.name                 # => "example"
  #   t.app[:config]         # => "/path/to/app/config"
  #   t.config_file          # => "/path/to/app/config/example.yml"
  #   t.config               # => {:one => 'ONE', :two => 'two', :three => 'three'}
  #
  # Tasks can be assembled into batches that enque and execute 
  # collectively. Batched tasks are automatically generated when a
  # config_file specifies an array of configurations.
  #
  #   # [/path/to/app/config/batch.yml]
  #   # - one: ONE
  #   # - one: ANOTHER ONE
  #
  #   t = ConfiguredTask.new "batch"
  #   t.batch.size           # => 2
  #   t1, t2 = t.batch
  #
  #   t1.name                # => "batch"
  #   t1.config              # => {:one => 'ONE', :two => 'two'}
  #
  #   t2.name                # => "batch"
  #   t2.config              # => {:one => 'ANOTHER ONE', :two => 'two'}
  #
  # === Batches
  #
  # Tasks facilitate batch processing of inputs using batched tasks.  Often 
  # a batch consists of the the same task class instantiated with a variety 
  # of configurations.  Once batched, tasks enque together; when any one of 
  # the tasks is enqued, the entire batch is enqued.
  #
  #   runlist = []
  #   t1 = Task.new {|task, input| runlist << input}
  #   t1.batch               # => [t1]
  #
  #   t2 = t1.initialize_batch_obj            
  #   t1.batch               # => [t1, t2]
  #   t2.batch               # => [t1, t2]
  #   
  #   t1.enq 1
  #   t2.enq 2
  #   t1.app.run
  #
  #   runlist                # => [1,1,2,2]
  #
  # Here runlist reflects that t1 and t2 were run in succession with the 1 
  # input, and then the 2 input. 
  #
  # === Non-Task Tasks
  #
  # The essential behavior of a Task is expressed in the Tap::Task::Base 
  # module.  Using this module, non-task classes can be made to behave like 
  # tasks.  An even more fundamental module, Tap::Executable, allows any 
  # method to behave in this manner.
  #
  # Configurations are specific to Task but batches are not.  Non-task 
  # tasks can be batched.  Executable methods cannot be batched.
  #
  # See Tap::Task::Base and Tap::Support::Executable for more details as 
  # well as Tap::Support::Rake::Task, which makes Rake[http://rake.rubyforge.org/] 
  # tasks behave like Tap tasks.
  class Task
   
    # Defines the essential behavior of a Task.  Using this module, 
    # non-task classes can be made to behave like tasks; ie they can 
    # be enqued, batched, and incorporated into workflows. 
    module Base 
      include Support::Executable
      
      attr_reader :app
      
      # Initializes obj to behave like a Task.  The input method will be
      # called when obj is run by Tap::App.
      def self.initialize(obj, method_name, app=App.instance)
        obj.extend Base
        obj.extend Support::Batchable
        obj.instance_variable_set(:@app, app)
        obj.instance_variable_set(:@batch, [])
        obj.instance_variable_set(:@multithread, false)
        obj.instance_variable_set(:@on_complete_block, nil)
        obj.instance_variable_set(:@_method_name, method_name)
        obj.initialize_batch_obj
        obj
      end
    
      # Enqueues self and self.batch to app with the inputs.  
      # The number of inputs provided should match the number 
      # of inputs specified by the arity of the _method_name method.
      def enq(*inputs)
        batch.each {|t| t.unbatched_enq(*inputs) }
        self
      end
      
      # Like enq, but only enques self and not self.batch.
      def unbatched_enq(*inputs)
        app.queue.enq(self, inputs)
      end
      
      alias :unbatched_on_complete :on_complete
      
      # Sets the on_complete_block for self and self.batch.
      # Use unbatched_on_complete to set the on_complete_block
      # for just self.
      def on_complete(override=false, &block)
        batch.each {|t| t.unbatched_on_complete(override, &block)}
        self
      end
      
      alias :unbatched_multithread= :multithread=
      
      # Sets the multithread for self and self.batch.  Use 
      # unbatched_multithread= to set multithread for just self.
      def multithread=(value)
        batch.each {|t| t.unbatched_multithread = value }
        self
      end
      
      # Raises a TerminateError if app.state == State::TERMINATE.
      # check_terminate may be called at any time to provide a 
      # breakpoint in long-running processes.
      def check_terminate
        if app.state == App::State::TERMINATE
          raise App::TerminateError.new
        end
      end      
    end
    
    include Support::Framework
    include Base
    
    attr_reader :task_block
    
    # Creates a new Task with the specified attributes.  
    #
    # === Subclassing
    # Batched tasks are generated by duplicating an existing instance, hence
    # it is a good idea to set shared instance variables BEFORE calling super
    # in a subclass initialize method.  Non-shared instance variables can be
    # set by overriding the initialize_batch_obj method:
    #
    #   class SubclassTask < Tap::Task
    #     attr_accessor :shared_variable, :instance_specific_variable
    #
    #     def initialize(*args)
    #       @shared_variable = Object.new
    #       super
    #     end
    #  
    #     def initialize_batch_obj(*args)
    #       task = super
    #       task.instance_specific_variable = Object.new
    #       task
    #     end
    #   end
    #
    #   t1 = SubclassTask.new
    #   t2 = t1.initialize_batch_obj
    #   t1.shared_variable == t2.shared_variable                           # => true
    #   t1.instance_specific_variable == t2.instance_specific_variable     # => false
    #
    def initialize(name=nil, config={}, app=App.instance, &task_block)
      @task_block = (task_block == nil ? default_task_block : task_block)
      @multithread = false
      @on_complete_block = nil
      @_method_name = :execute
      super(name, config, app)
    end
    
    # Executes self with the given inputs.  Execute provides hooks for subclasses
    # to insert standard execution code: before_execute, on_execute_error,
    # and after_execute.  Override any/all of these methods as needed.
    #
    # Execute passes the inputs to process and returns the result.
    def execute(*inputs)  
      before_execute
      begin
        result = process(*inputs)
      rescue
        on_execute_error($!)
      end
      after_execute
       
      result
    end
    
    # The method for processing inputs into outputs.  Override this method in
    # subclasses to provide class-specific process logic.  The number of 
    # arguments specified by process corresponds to the number of arguments
    # the task should have when enqued.  
    #
    #   class TaskWithTwoInputs < Tap::Task
    #     def process(a, b)
    #       [b,a]
    #     end
    #   end
    #
    #   t = TaskWithTwoInputs.new
    #   t.enq(1,2).enq(3,4)
    #   t.app.run
    #   t.app.results(t)         # => [[2,1], [4,3]]
    #
    # By default process passes self and the input(s) to the task_block   
    # provided during initialization.  In this case the task block dictates  
    # the number of arguments enq should receive.  Simply returns the inputs
    # if no task_block is set.
    #
    #   # two arguments in addition to task are specified
    #   # so this Task must be enqued with two inputs...
    #   t = Task.new {|task, a, b| [b,a] }
    #   t.enq(1,2).enq(3,4)
    #   t.app.run
    #   t.app.results(t)         # => [[2,1], [4,3]]
    #
    def process(*inputs)
      return inputs if task_block == nil
      inputs.unshift(self)
      
      arity = task_block.arity
      n = inputs.length
      unless n == arity || (arity < 0 && (-1-n) <= arity) 
        raise ArgumentError.new("wrong number of arguments (#{n} for #{arity})")
      end
      
      task_block.call(*inputs)
    end

    # Logs the inputs to the application logger (via app.log)
    def log(action, msg="", level=Logger::INFO)
      # TODO - add a task identifier?
      app.log(action, msg, level)
    end
    
    # Returns self.name
    def to_s
      name
    end
    
    protected
    
    # Hook to set a default task block.  By default, nil.
    def default_task_block
      nil
    end
    
    # Hook to execute code before inputs are processed.
    def before_execute() end
  
    # Hook to execute code after inputs are processed.
    def after_execute() end

    # Hook to handle unhandled errors from processing inputs on a task level.  
    # By default on_execute_error simply re-raises the unhandled error.
    def on_execute_error(err)
      raise err
    end
  end
end