require 'logger'
require 'tap/support/aggregator'
require 'tap/support/executable_queue'

module Tap
  module Support
    autoload(:Combinator, 'tap/support/combinator')
  end
  
  # App coordinates the setup and running of tasks, and provides an interface 
  # to the application directory structure.  App is convenient for use within 
  # scripts and, with Env, provides the basis for the 'tap' command line 
  # application.  
  #
  # === Running Tasks
  #
  # All tasks have an App (by default App.instance) through which tasks access
  # access application-wide resources like the logger.  Additionally, task
  # enque command are forwarded to App#enq:
  #
  #   t1 = Task.new {|task, input| input += 1 }
  #   t1.enq(0)
  #   app.enq(t1, 1)
  #
  #   app.run
  #   app.results(t1)                # => [1, 2]
  #
  # When a task completes, the results will either be passed to the task
  # <tt>on_complete</tt> block (if set) or be collected into an Aggregator;
  # aggregated results may be accessed per-task, as shown above.  Task 
  # <tt>on_complete</tt> blocks typically enque other tasks, allowing the
  # construction of imperative workflows:
  #
  #   # clear the previous results
  #   app.aggregator.clear
  #
  #   t2 = Task.new {|task, input| input += 10 }
  #   t1.on_complete {|_result| t2.enq(_result) }
  #
  #   t1.enq 0
  #   t1.enq 10
  #
  #   app.run
  #   app.results(t1)                # => []
  #   app.results(t2)                # => [11, 21]
  #
  # Here t1 has no results because the on_complete block passed them to t2 in 
  # a simple sequence.
  #
  # ==== Dependencies
  #
  # Tasks allow the construction of dependency-based workflows as well; tasks
  # may be set to depend on other tasks such that the dependent task only 
  # executes after the dependencies have been resolved (ie executed with a
  # given set of inputs).
  #
  #   array = []
  #   t1 = Task.new {|task, *inputs| array << inputs }
  #   t2 = Task.new {|task, *inputs| array << inputs }
  #
  #   t1.depends_on(t2,1,2,3)
  #   t1.enq(4,5,6)
  #
  #   app.run
  #   array                          # => [[1,2,3], [4,5,6]]
  #
  # Once a dependency is resolved, it will not execute again:
  #
  #   t1.enq(7,8)
  #   app.run
  #   array                          # => [[1,2,3], [4,5,6], [7,8]]
  #
  # ==== Batching
  #
  # Tasks can be batched, allowing the same input to be enqued to multiple 
  # tasks at once.
  #
  #   t1 = Task.new  {|task, input| input += 1 }
  #   t2 = Task.new  {|task, input| input += 10 }
  #   Task.batch(t1, t2)             # => [t1, t2]
  #
  #   t1.enq 0
  #
  #   app.run
  #   app.results(t1)                # => [1]
  #   app.results(t2)                # => [10]
  #
  # ==== Executables
  #
  # App can use any Executable object in place of a task. One way to initialize 
  # an Executable for a method is to use the Object#_method defined by Tap.  The 
  # result can be enqued and incorporated into workflows, but they cannot be 
  # batched.
  #
  # The mq (method enq) method generates and enques the method in one step.
  #
  #   array = []
  #   m = array._method(:push)
  #    
  #   app.enq(m, 1)
  #   app.mq(array, :push, 2)
  #
  #   array.empty?                   # => true
  #   app.run
  #   array                          # => [1, 2]
  #
  # === Auditing
  # 
  # All results generated by executable methods are audited to track how a given  
  # input evolves during a workflow.   
  #
  # To illustrate auditing, consider a workflow that uses the 'add_one' method 
  # to add one to an input until the result is 3, then adds five more with the 
  # 'add_five' method.  The final result should always be 8.  
  #
  #   t1 = Tap::Task.new {|task, input| input += 1 }
  #   t1.name = "add_one"
  #
  #   t2 = Tap::Task.new {|task, input| input += 5 }
  #   t2.name = "add_five"
  #
  #   t1.on_complete do |_result|
  #     # _result is the audit; use the _current method
  #     # to get the current value in the audit trail
  #
  #     _result._current < 3 ? t1.enq(_result) : t2.enq(_result)
  #   end
  #   
  #   t1.enq(0)
  #   t1.enq(1)
  #   t1.enq(2)
  #
  #   app.run
  #   app.results(t2)                # => [8,8,8]
  #
  # Although the results are indistinguishable, each achieved the final value
  # through a different series of tasks. With auditing you can see how each 
  # input came to the final value of 8:
  #
  #   # app.results returns the actual result values
  #   # app._results returns the audits for these values
  #   app._results(t2).each do |_result|
  #     puts "How #{_result._original} became #{_result._current}:"
  #     puts _result._to_s
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
    # methods that have no <tt>on_complete</tt> block
    attr_reader :aggregator
    
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
    
    #
    # Execution methods
    #
    
    # Executes the input Executable with the inputs.  Stores the result in 
    # aggregator unless an on_complete block is set.  Returns the audited 
    # result.
    def execute(m, inputs)
      _result = m._execute(*inputs)
      aggregator.store(_result) unless m.on_complete_block
      _result
    end

    # Sets state = State::READY unless the app is running.  Returns self.
    def ready
      self.state = State::READY unless self.state == State::RUN
      self
    end

    # Sequentially calls execute with the Executable methods and inputs in 
    # queue; run continues until the queue is empty and then returns self. 
    # Calls to run when already running will return immediately.
    #
    # Run checks the state of self before executing a method.  If the state is 
    # changed to State::STOP, then no more methods will be executed; currently 
    # running methods will continute to completion.  If the state is changed to 
    # State::TERMINATE then no more methods will be executed and currently 
    # running methods will be discontinued as described in terminate.
    def run
      return self unless state == State::READY
      self.state = State::RUN

      # TODO: log starting run
      begin
        until queue.empty? || state != State::RUN
          execute(*queue.deq)
        end
      rescue(TerminateError)
        # gracefully fail for termination errors
      rescue(Exception)
        # handle other errors accordingly
        raise if debug?
        log($!.class, $!.message)
      ensure
        self.state = State::READY
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
      self.state = State::STOP if self.state == State::RUN
      self
    end

    # Signals a running application to terminate execution by setting 
    # state = State::TERMINATE.  In this state, an executing task 
    # will then raise a TerminateError upon check_terminate, thus 
    # allowing the invocation of task-specific termination, perhaps 
    # performing rollbacks. (see Tap::Task#check_terminate).
    #
    # Does nothing if state == State::READY.
    def terminate
      self.state = State::TERMINATE unless self.state == State::READY
      self
    end
    
    # Returns an information string for the App.  
    #
    #   App.instance.info   # => 'state: 0 (READY) queue: 0 results: 0'
    #
    # Provided information:
    #
    # state:: the integer and string values of self.state
    # queue:: the number of methods currently in the queue
    # results:: the total number of results in aggregator
    def info
      "state: #{state} (#{State.state_str(state)}) queue: #{queue.size} results: #{aggregator.size}"
    end
    
    # Enques the task with the inputs.  If the task is batched, then each 
    # task in task.batch will be enqued with the inputs.  Returns task.
    #
    # An Executable may provided instead of a task.
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
    
    # Sets a sequence workflow pattern for the tasks; each task will enque 
    # the next task with it's results.
    #
    # Notes:
    # - Batched tasks will have the pattern set for each task in the batch 
    # - The current audited results are yielded to the block, if given, 
    #   before the next task is enqued.
    # - Executables may provided as well as tasks.
    def sequence(tasks) # :yields: _result
      current_task = tasks.shift
      tasks.each do |next_task|
        # simply pass results from one task to the next.  
        current_task.on_complete do |_result| 
          yield(_result) if block_given?
          enq(next_task, _result)
        end
        current_task = next_task
      end
    end

    # Sets a fork workflow pattern for the source task; each target
    # will enque the results of source.
    #
    # Notes:
    # - Batched tasks will have the pattern set for each task in the batch 
    # - The current audited results are yielded to the block, if given, 
    #   before the next task is enqued.
    # - Executables may provided as well as tasks.
    def fork(source, targets) # :yields: _result
      source.on_complete do |_result|
        targets.each do |target| 
          yield(_result) if block_given?
          enq(target, _result)
        end
      end
    end
    
    # Sets a simple merge workflow pattern for the source tasks. Each source
    # enques target with it's result; no synchronization occurs, nor are 
    # results grouped before being sent to the target.
    #
    # Notes:
    # - Batched tasks will have the pattern set for each task in the batch 
    # - The current audited results are yielded to the block, if given, 
    #   before the next task is enqued.
    # - Executables may provided as well as tasks.
    def merge(target, sources) # :yields: _result
      sources.each do |source|
        # merging can use the existing audit trails... each distinct 
        # input is getting sent to one place (the target)
        source.on_complete do |_result| 
          yield(_result) if block_given?
          enq(target, _result)
        end
      end
    end
    
    # Sets a synchronized merge workflow for the source tasks.  Results from
    # each source task are collected and enqued as a single group to the target. 
    # The target is not enqued until all sources have completed.  Raises an
    # error if a source returns twice before the target is enqued.
    #
    # Notes:
    # - Batched tasks will have the pattern set for each task in the batch 
    # - The current audited results are yielded to the block, if given, 
    #   before the next task is enqued.
    # - Executables may provided as well as tasks.
    #
    #-- TODO: add notes on testing and the way results are received
    # (ie as a single object)
    def sync_merge(target, sources) # :yields: _result
      group = Array.new(sources.length, nil)
      sources.each_with_index do |source, index|
        batch_map = Hash.new(0)
        batch_length = if source.kind_of?(Support::Batchable)
          source.batch.each_with_index {|obj, i| batch_map[obj] = i }
          source.batch.length
        else
          1
        end
        
        group[index] = Array.new(batch_length, nil)
        
        source.on_complete do |_result|
          batch_index = batch_map[_result._current_source]

          if group[index][batch_index] != nil
            raise "sync_merge collision... already got a result for #{_result._current_source}"
          end

          group[index][batch_index] = _result
          
          unless group.flatten.include?(nil)
            Support::Combinator.new(*group).each do |*combination|
              # merge the source audits
              _group_result = Support::Audit.merge(*combination)
            
              yield(_group_result) if block_given?
              target.enq(_group_result)
            end
            
            # reset the group array
            group.collect! {|i| nil }
          end 
        end
      end
    end
    
    # Sets a choice workflow pattern for the source task.  When the
    # source task completes, switch yields the audited result to the 
    # block which then returns the index of the target to enque with 
    # the results. No target will be enqued if the index is false or 
    # nil; an error is raised if no target can be found for the 
    # specified index.
    #
    # Notes:
    # - Batched tasks will have the pattern set for each task in the batch 
    # - The current audited results are yielded to the block, if given, 
    #   before the next task is enqued.
    # - Executables may provided as well as tasks.
    def switch(source, targets) # :yields: _result
      source.on_complete do |_result| 
        if index = yield(_result)        
          unless target = targets[index] 
            raise "no switch target for index: #{index}"
          end
          
          enq(target, _result)
        else
          aggregator.store(_result)
        end
      end
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
    #   t1 = Task.new  {|task, input| input += 1 }
    #   t2 = Task.new  {|task, input| input += 10 }
    #   t3 = t2.initialize_batch_obj
    #
    #   t1.enq(0)
    #   t2.enq(1)
    #
    #   app.run
    #   app.results(t1, t2.batch)     # => [1, 11, 11]
    #   app.results(t2, t1)           # => [11, 1]
    #
    def results(*tasks)
      _results(tasks).collect {|_result| _result._current}
    end
    
    protected
    
    # A hook for handling unknown configurations in subclasses, called from
    # configure.  If handle_configuration evaluates to false, then configure
    # raises an error.
    def handle_configuation(key, value)
      false
    end
    
    # Sets the state of the application
    attr_writer :state

    # TerminateErrors are raised to kill executing tasks when terminate is 
    # called on an running App.  They are handled by the run rescue code.
    class TerminateError < RuntimeError 
    end
  end
end