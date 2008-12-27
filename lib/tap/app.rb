require 'logger'
require 'tap/support/aggregator'
require 'tap/support/dependencies'
require 'tap/support/executable_queue'

module Tap
  
  # App coordinates the setup and running of tasks, and provides an interface 
  # to the application directory structure. All tasks have an App (by default
  # App.instance) through which tasks access access application-wide resources 
  # like the logger, executable queue, aggregator, and dependencies.
  #
  # === Running Tasks
  #
  # Task enque command are forwarded to App#enq:
  #
  #   t0 = Task.intern {|task, input| "#{input}.0" }
  #   t0.enq('a')
  #   app.enq(t0, 'b')
  #
  #   app.run
  #   app.results(t0)                # => ['a.0', 'b.0']
  #
  # When a task completes, the results will be passed to the task on_complete
  # block, if set, or be collected into an Aggregator (aggregated results may 
  # be accessed per-task, as shown above); on_complete blocks typically 
  # execute or enque other tasks, allowing the construction of imperative
  # workflows:
  #
  #   # clear the previous results
  #   app.aggregator.clear
  #
  #   t1 = Task.intern {|task, input| "#{input}.1" }
  #   t0.on_complete {|_result| t1.enq(_result) }
  #   t0.enq 'c'
  #
  #   app.run
  #   app.results(t0)                # => []
  #   app.results(t1)                # => ['c.0.1']
  #
  # Here t0 has no results because the on_complete block passed them to t1 in 
  # a simple sequence.
  #
  # === Dependencies
  #
  # Tasks allow the construction of dependency-based workflows such that a 
  # dependent task only executes after its dependencies have been resolved.
  #
  #   runlist = []
  #   t0 = Task.intern {|task| runlist << task }
  #   t1 = Task.intern {|task| runlist << task }
  #
  #   t0.depends_on(t1)
  #   t0.enq
  #
  #   app.run
  #   runlist                        # => [t1, t0]
  #
  # Once a dependency is resolved, it will not execute again:
  #
  #   t0.enq
  #   app.run
  #   runlist                        # => [t1, t0, t0]
  #
  # === Batching
  #
  # Tasks can be batched, allowing the same input to be enqued to multiple 
  # tasks at once.
  #
  #   t0 = Task.intern  {|task, input| "#{input}.0" }
  #   t1 = Task.intern  {|task, input| "#{input}.1" }
  #
  #   t0.batch_with(t1)
  #   t0.enq 'a'
  #   t1.enq 'b'
  #
  #   app.run
  #   app.results(t0)                # => ['a.0', 'b.0']
  #   app.results(t1)                # => ['a.1', 'b.1']
  #
  # === Executables
  #
  # App can enque and run any Executable object. Arbitrary methods may be
  # made into Executables using Object#_method. The mq (method enq) method
  # generates and enques methods in one step.
  #
  #   array = []
  #
  #   # longhand
  #   m = array._method(:push)
  #   m.enq(1)
  #
  #   # shorthand
  #   app.mq(array, :push, 2)
  #
  #   array.empty?                   # => true
  #   app.run
  #   array                          # => [1, 2]
  #
  # === Auditing
  # 
  # All results are audited to track how a given input evolves during a workflow.
  # To illustrate auditing, consider and addition workflow that ends in eights.
  #
  #   add_one  = Tap::Task.intern({}, 'add_one')  {|task, input| input += 1 }
  #   add_five = Tap::Task.intern({}, 'add_five') {|task, input| input += 5 }
  #
  #   add_one.on_complete do |_result|
  #     # _result is the audit
  #     current_value = _result.value
  #
  #     if current_value < 3 
  #       add_one.enq(_result)
  #     else
  #       add_five.enq(_result)
  #     end
  #   end
  #   
  #   add_one.enq(0)
  #   add_one.enq(1)
  #   add_one.enq(2)
  #
  #   app.run
  #   app.results(add_five)          # => [8,8,8]
  #
  # Although the results are indistinguishable, each achieved the final value
  # through a different series of tasks. With auditing you can see how each 
  # input came to the final value of 8:
  #
  #   # app.results returns the actual result values
  #   # app._results returns the audits for these values
  #   app._results(add_five).each do |_result|
  #     puts "How #{_result._original} became #{_result.value}:"
  #     puts _result.dump
  #     puts
  #   end
  #
  # Prints:
  #
  #   How 2 became 8:
  #   o-[] 2
  #   o-[add_one] 3
  #   o-[add_five] 8
  #
  #   How 1 became 8:
  #   o-[] 1
  #   o-[add_one] 2
  #   o-[add_one] 3
  #   o-[add_five] 8
  #
  #   How 0 became 8:
  #   o-[] 0
  #   o-[add_one] 1
  #   o-[add_one] 2
  #   o-[add_one] 3
  #   o-[add_five] 8
  #
  # See Tap::Support::Audit for more details.
  class App < Root
    class << self
      # Sets the current app instance
      attr_writer :instance
      
      # Returns the current instance of App.  If no instance has been set,
      # then a new App with the default configuration will be initialized. 
      def instance
        @instance ||= App.new
      end
    end

    # The shared logger
    attr_reader :logger
    
    # The application queue
    attr_reader :queue
    
    # The state of the application (see App::State)
    attr_reader :state
    
    # A Tap::Support::Aggregator to collect the results of 
    # methods that have no on_complete block
    attr_reader :aggregator
    
    # A Tap::Support::Dependencies to track dependencies.
    attr_reader :dependencies
    
    config :debug, false, &c.flag                 # Flag debugging
    config :force, false, &c.flag                 # Force execution at checkpoints
    config :quiet, false, &c.flag                 # Suppress logging
    config :verbose, false, &c.flag               # Enables extra logging (overrides quiet)
    
    # The constants defining the possible App states.  
    module State
      READY = 0
      RUN = 1
      STOP = 2
      TERMINATE = 3
      
      module_function
      
      # Returns the string corresponding to the input state value.  
      # Returns nil for unknown states.
      #
      #   State.state_str(0)        # => 'READY'
      #   State.state_str(12)       # => nil
      def state_str(state)
        constants.inject(nil) {|str, s| const_get(s) == state ? s.to_s : str}
      end
    end  
    
    # Creates a new App with the given configuration.  
    def initialize(config={}, logger=DEFAULT_LOGGER)
      super()
      
      @state = State::READY
      @queue = Support::ExecutableQueue.new
      @aggregator = Support::Aggregator.new
      @dependencies = Support::Dependencies.new
      
      initialize_config(config)
      self.logger = logger
    end
    
    # The default App logger writes to $stdout at level INFO.
    DEFAULT_LOGGER = Logger.new($stdout)
    DEFAULT_LOGGER.level = Logger::INFO
    DEFAULT_LOGGER.formatter = lambda do |severity, time, progname, msg|
      "  %s[%s] %18s %s\n" % [severity[0,1], time.strftime('%H:%M:%S') , progname || '--' , msg]
    end
    
    # True if debug or the global variable $DEBUG is true.
    def debug?
      debug || $DEBUG
    end
    
    # Sets the current logger. The logger level is set to Logger::DEBUG if
    # debug? is true.
    def logger=(logger)
      unless logger.nil?
        logger.level = Logger::DEBUG if debug?
      end
      
      @logger = logger
    end
    
    # Logs the action and message at the input level (default INFO).  
    # Logging is suppressed if quiet is true.
    def log(action, msg="", level=Logger::INFO)
      logger.add(level, msg, action.to_s) if !quiet || verbose
    end
    
    # Returns the configuration filepath for the specified task name,
    # File.join(app['config'], task_name + ".yml"). Returns nil if 
    # task_name is nil.
    def config_filepath(name)
      name == nil ? nil : filepath('config', "#{name}.yml")
    end
    
    # Sets state = State::READY unless the app is running.  Returns self.
    def ready
      @state = State::READY unless state == State::RUN
      self
    end

    # Sequentially calls execute with the [executable, inputs] pairs in
    # queue; run continues until the queue is empty and then returns self.
    #
    # ==== Run State
    #
    # Run checks the state of self before executing a method. If state
    # changes from State::RUN, the following behaviors result:
    # 
    # State::STOP:: No more executables will be executed; the current
    #               executable will continute to completion.
    # State::TERMINATE:: No more executables will be executed and the
    #                    currently running executable will be
    #                    discontinued as described in terminate.
    #
    # Calls to run when the state is not State::READY do nothing and
    # return immediately.
    def run
      return self unless state == State::READY
      @state = State::RUN

      # TODO: log starting run
      begin
        until queue.empty? || state != State::RUN
          executable, inputs = queue.deq
          executable._execute(*inputs)
        end
      rescue(TerminateError)
        # gracefully fail for termination errors
      rescue(Exception)
        # handle other errors accordingly
        raise if debug?
        log($!.class, $!.message)
      ensure
        @state = State::READY
      end
      
      # TODO: log run complete
      self
    end
    
    # Signals a running application to stop executing tasks in the 
    # queue by setting state = State::STOP.  The task currently 
    # executing will continue uninterrupted to completion.
    #
    # Does nothing unless state is State::RUN.
    def stop
      @state = State::STOP if state == State::RUN
      self
    end

    # Signals a running application to terminate execution by setting 
    # state = State::TERMINATE.  In this state, an executing task 
    # will then raise a TerminateError upon check_terminate, thus 
    # allowing the invocation of task-specific termination, perhaps 
    # performing rollbacks. (see Tap::Support::Executable#check_terminate).
    #
    # Does nothing if state == State::READY.
    def terminate
      @state = State::TERMINATE unless state == State::READY
      self
    end
    
    # Returns an information string for the App.  
    #
    #   App.instance.info   # => 'state: 0 (READY) queue: 0 results: 0'
    #
    def info
      "state: #{state} (#{State.state_str(state)}) queue: #{queue.size} results: #{aggregator.size}"
    end
    
    # Enques the task (or Executable) with the inputs.  If the task is batched, 
    # then each task in task.batch will be enqued with the inputs.  Returns task.
    def enq(task, *inputs)
      case task
      when Tap::Task
        raise ArgumentError, "not assigned to enqueing app: #{task}" unless task.app == self
        task.enq(*inputs)
      when Support::Executable
        queue.enq(task, inputs)
      else
        raise ArgumentError, "not a Task or Executable: #{task}"
      end
      task
    end

    # Method enque.  Enques the specified method from object with the inputs.
    # Returns the enqued method.
    def mq(object, method_name, *inputs)
      m = object._method(method_name)
      enq(m, *inputs)
    end
        
    # Returns all aggregated, audited results for the specified tasks.  
    # Results are joined into a single array.  Arrays of tasks are 
    # allowed as inputs. See results.
    def _results(*tasks)
      aggregator.retrieve_all(*tasks.flatten)
    end
    
    # Returns all aggregated results for the specified tasks.  Results are
    # joined into a single array.  Arrays of tasks are allowed as inputs.    
    #
    #   t0 = Task.intern  {|task, input| "#{input}.0" }
    #   t1 = Task.intern  {|task, input| "#{input}.1" }
    #   t2 = Task.intern  {|task, input| "#{input}.2" }
    #   t1.batch_with(t2)
    #
    #   t0.enq(0)
    #   t1.enq(1)
    #
    #   app.run
    #   app.results(t0, t1.batch)     # => ["0.0", "1.1", "1.2"]
    #   app.results(t1, t0)           # => ["1.1", "0.0"]
    #
    def results(*tasks)
      _results(tasks).collect {|_result| _result.value }
    end
    
    def inspect
      "#<#{self.class.to_s}:#{object_id} root: #{root} >"
    end
    
    # TerminateErrors are raised to kill executing tasks when terminate is 
    # called on an running App.  They are handled by the run rescue code.
    class TerminateError < RuntimeError 
    end
  end
end