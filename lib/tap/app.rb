module Tap
  
  # = Overview
  #
  # App coordinates the setup and running of tasks, and provides an interface 
  # to the application directory structure.  App is convenient for use within 
  # scripts, and provides the basis for the 'tap' command line application.  
  #
  # === Task Setup
  #
  # All tasks have an App (by default App.instance) which helps initialize the 
  # task by loading configuration templates from the config directory.  Say
  # we had the following configuration files:
  # 
  #   [/path/to/app/config/some/task.yml]
  #   key: one
  #
  #   [/path/to/app/config/another/task.yml]
  #   key: two
  #
  # Tasks initialized with the names 'some/task' and 'another/task' will 
  # be cofigured by App like this:
  #
  #   app = App.instance
  #   app.root                           # => '/path/to/app'
  #   app[:config]                       # => '/path/to/app/config'
  # 
  #   some_task = Task.new 'some/task'
  #   some_task.app                      # => App.instance
  #   some_task.config_file              # => '/path/to/app/config/some/task.yml'
  #   some_task.config                   # => {:key => 'one'}
  #
  #   another_task = Task.new 'another/task'
  #   another_task.app                   # => App.instance
  #   another_task.config_file           # => '/path/to/app/config/another/task.yml'
  #   another_task.config                # => {:key => 'two'}
  #
  # If app[:config] referenced a different directory then the tasks would be 
  # initialized from files relative to that location.  
  #
  # (see Tap::Root for more details) 
  #
  # === Running Tasks
  #
  # Task enque commands are passed to app, and tasks access application-wide
  # resources like the logger and options through App.  
  #
  #   t1 = Task.new {|task, input| input += 1 }
  #   t1.enq 0
  #   t1.enq 10
  #
  #   app.run
  #   app.results(t1)                # => [1, 11]
  #
  # When a task completes, app collects its results into a data structure that 
  # allows access to them as shown above.  This behavior can be modified by 
  # setting an on_complete block for the task; on_complete blocks can be used 
  # to pass results among tasks, allowing the construction of workflows.
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
  # === Running Methods
  #
  # Running a task really consists of calling a method.  For tasks, the method is
  # basically the block you provide to Task.new, although execution is mediated by 
  # Tap::Task#execute and Tap::Task#process so that the block receives the task
  # as a standard input.  In subclasses, the method corresponds to the subclass
  # 'process' method.  
  #
  #   # the block is called to add one to the input
  #   Task.new  {|task, input| input += 1 }
  #
  #   # same thing, but now in a subclass
  #   class AddOne < Tap::Task
  #     def process(input) input += 1 end
  #   end
  #
  # When tasks are enqued, their executable method is pushed onto the queue along
  # with the inputs for the method. Tasks can be batched such that the executable 
  # methods of several tasks are enqued at the same time, allowing you to feed the
  # same inputs to multiple methods at once.
  #
  #   t1 = Task.new  {|task, input| input += 1 }
  #   t2 = Task.new  {|task, input| input += 10 }
  #   Task.batch(t1, t2)             # => [t1, t2]
  #
  #   t1.enq 0
  #   t2.enq 10
  #
  #   app.run
  #   app.results(t1)                # => [1, 11]
  #   app.results(t2)                # => [10, 20]
  #
  # App also supports multithreading; multithreaded methods execute cosynchronously, 
  # each on their own thread (of course, you need to take care to make each method
  # thread safe).
  #
  #   lock = Mutex.new
  #   array = []
  #   t1 = Task.new  {|task| lock.synchronize { array << Thread.current.object_id }; sleep 0.1 }
  #   t2 = Task.new  {|task| lock.synchronize { array << Thread.current.object_id }; sleep 0.1 }
  #   
  #   t1.multithread = true
  #   t1.enq
  #   t2.multithread = true
  #   t2.enq
  #
  #   app.run
  #   array.length                   # => 2
  #   array[0] == array[1]           # => false
  #
  # Since App is geared towards methods, methods from non-task objects can get 
  # hooked into a workflow as needed.  
  #---
  # TODO REVISIT
  #
  # The preferred way to do so is to make the
  # non-task objects behave like tasks using Task::Base#initialize.  The objects
  # can now be enqued, incorporated into workflows, and batched.
  #
  #   array = []
  #   Task::Base.initialize(array, :push)
  #
  #   array.enq(1)
  #   array.enq(2)
  #
  #   array.empty?                   # => true
  #   app.run
  #   array                          # => [1, 2]
  #
  # Lastly, if you can't or don't want to turn your object into a task, 
  #++
  # Tap defines 
  # Object#_method to generate executable objects that can be enqued and 
  # incorporated into workflows, although they cannot be batched.  The mq 
  # (method enq) method generates and enques the method in one step.
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
  # App keeps  running as long as it finds methods in the queue, or until it is stopped 
  # or terminated.  
  #
  # (see Tap::Support::Executable, Tap::Task, and Tap::Task::Base for more details)
  #
  # === Auditing
  # 
  # All results generated by methods are audited to track how a given input 
  # evolves during a workflow.   
  #
  # To illustrate auditing, consider a workflow that uses the 'add_one' method 
  # to add one to an input until the result is 3, then adds five more with the 
  # 'add_five' method.  The final result should always be 8.  
  #
  #   t1 = Tap::Task.new('add_one') {|task, input| input += 1 }
  #   t2 = Tap::Task.new('add_five') {|task, input| input += 5 }
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
    include MonitorMixin

    class << self
      # Sets the current app instance
      attr_writer :instance
      
      # Returns the current instance of App.  If no instance has been set,
      # then a new App with the default configuration will be initialized. 
      def instance
        @instance ||= App.new
      end
    end
    
    # An OpenStruct containing the application options.
    attr_reader :options
    
    # The shared logger. 
    attr_reader :logger
    
    # The application queue.
    attr_reader :queue
    
    # The state of the application (see App::State).
    attr_reader :state
    
    # A hash of (task_name, task_class_name) pairs mapping names to 
    # classes for instantiating tasks that have a non-default name.   
    # See task_class_name for more details.
    attr_accessor :map
    
    # A Tap::Support::Aggregator to collect the results of 
    # methods that have no on_complete block.
    attr_reader :aggregator
    
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
    
    DEFAULT_MAX_THREADS = 10
    
    # Creates a new App with the given configuration.  
    # See reconfigure for configuration options.
    def initialize(config={})
      super()
      
      @state = State::READY
      @threads = [].extend(MonitorMixin)
      @thread_queue = nil
      @run_thread = nil
      
      @queue = Support::ExecutableQueue.new
      @aggregator = Support::Aggregator.new

      # defaults must be provided for options and logging to ensure
      # that they will be initialized by reconfigure 
      self.reconfigure( {
        :options => {}, :logger => {}, :map => {}
      }.merge(config) )
    end
    
    # Clears the queue and aggregator.
    #def clear(options={})
    #  # syncrhonize?
    #  ready
    #  raise "cannot clear unless state == READY" unless state == State::READY
    #
    #  queue.clear
    #  aggregator.clear
    #end
    
    # True if options.debug or the global variable $DEBUG is true.
    def debug?
      options.debug || $DEBUG ? true : false
    end
     
    # Returns the configuration of self.  
    def config 
      {:root => self.root,
      :directories => self.directories,
      :absolute_paths => self.absolute_paths,
      :options => self.options.marshal_dump,
      :logger => {
        :device => self.logger.logdev.dev,
        :level => self.logger.level,
        :datetime_format => self.logger.datetime_format}}      
    end
    
    # Reconfigures self with the input configurations; other configurations are not affected.
    #
    #   app = Tap::App.new :root => "/root", :directories => {:dir => 'path/to/dir'}
    #   app.reconfigure(
    #     :root => "./new/root",
    #     :logger => {:level => Logger::DEBUG})
    #
    #   app.root           # => File.expand_path("./new/root")
    #   app[:dir]          # => File.expand_path("./new/root/path/to/dir")
    #   app.logger.level   # => Logger::DEBUG
    #
    # Available configurations:
    # root:: resets the root directory of self using root=
    # directories:: resets directory aliases using directories= (note ALL  
    #               aliases are reset. use app[dir]= to set a single alias)
    # absolute_paths:: resets absolute path aliases using absolute_paths= (note ALL  
    #               aliases are reset. use app[dir]= to set a single alias)
    # options:: resets the application options (note ALL options are reset.   
    #           use app.options.opt= to set a single option)
    # logger:: creates and sets a new logger from the configuration 
    #
    # Available logger configurations and defaults:
    # device:: STDOUT
    # level:: INFO (1) 
    # datetime_format:: %H:%M:%S
    #
    # Unknown configurations raise an error.  
    def reconfigure(config={})
      config = config.symbolize_keys
  
      # ensure critical keys are evaluated in the proper order
      keys = [:root, :directories, :absolute_paths, :options]
      config.keys.each do |key|
        keys << key unless keys.include?(key)
      end 
      
      keys.each do |key|
        next unless config.has_key?(key)
        value = config[key]
        
        case key
        when :root
          self.root = value
        when :directories 
          self.directories = value
        when :absolute_paths 
          self.absolute_paths = value
        when :options
          @options = OpenStruct.new
          value.each_pair {|k,v| options.send("#{k}=", v) }
        when :logger
          log_config = {
            :device => STDOUT,
            :level => 'INFO',
            :datetime_format => '%H:%M:%S'
          }.merge(value.symbolize_keys)

          logger = Logger.new(log_config[:device]) 
          logger.level = log_config[:level].kind_of?(String) ? Logger.const_get(log_config[:level]) : log_config[:level]
          logger.datetime_format = log_config[:datetime_format]    
          self.logger = logger
        when :map
          self.map = value
        else
          unless handle_configuation(key, value)
            if block_given? 
              yield(key, value)
            else
              raise ArgumentError.new("Unknown configuration: #{key}")
            end
          end
        end
      end
      
      self
    end
    
    # Unloads constants loaded by Dependencies, so that they will be reloaded
    # (with any changes made) next time they are called.  Returns the unloaded 
    # constants.  
    def reload
      unloaded = []
      
      # echos the behavior of Dependencies.clear, 
      # but collects unloaded constants
      Dependencies.loaded.clear
      Dependencies.autoloaded_constants.each do |const| 
        Dependencies.remove_constant const
        unloaded << const
      end
      Dependencies.autoloaded_constants.clear
      Dependencies.explicitly_unloadable_constants.each do |const| 
        Dependencies.remove_constant const
        unloaded << const
      end
      
      unloaded
    end
    
    # Looks up the specified constant, dynamically loading via Dependencies
    # if necessary.  Returns the const_name if const_name is a Module.
    # Yields to the optional block if the constant cannot be found; otherwise
    # raises a LookupError.
    def lookup_const(const_name)
      return const_name if const_name.kind_of?(Module)
      
      begin
        const_name = const_name.camelize
        
        case RUBY_VERSION
        when /^1.9/
          
          # a check is necessary to maintain the 1.8 behavior  
          # of lookup_const in 1.9, where ancestor constants 
          # may be returned by a direct evaluation
          const_name.split("::").inject(Object) do |current, const|
            const = const.to_sym
            
            current.const_get(const).tap do |c|
              unless current.const_defined?(const, false)
                raise NameError.new("uninitialized constant #{const_name}") 
              end
            end
          end

        else 
          const_name.constantize
        end
       
      rescue(NameError)
        if block_given?
          yield 
        else
          raise LookupError.new("unknown constant: #{const_name}")
        end
      end
    end
    
    #
    # Logging methods
    #
    
    # Sets the current logger.  The logger is extended with Support::Logger to provide 
    # additional logging capabilities.  The logger level is set to Logger::DEBUG if 
    # the global variable $DEBUG is true.
    def logger=(logger)
      @logger = logger
      @logger.extend Support::Logger unless @logger.nil?
      @logger.level = Logger::DEBUG if $DEBUG
      @logger
    end
    
    # Logs the action and message at the input level (default INFO).  
    # Logging is suppressed if options.quiet
    def log(action, msg="", level=Logger::INFO)
      logger.add(level, msg, action.to_s) unless options.quiet
    end
    
    # EXPERIMENTAL
    #
    # Formatted log.  Works like log, but passes the current log format to the
    # block and uses whatever format the block returns.  The format recieves 
    # the following arguments like so:
    #
    #  format % [severity, timestamp, (action || '--'), msg]
    #
    # By default, if you don't specify a block, flog just chomps a newline off
    # the format, so your log will be inline.
    #
    # BUG: Not thread safe at the moment.
    def flog(action="", msg="", level=Logger::INFO) # :yields: format
      unless options.quiet
        logger.format_add(level, msg, action) do |format| 
          block_given? ? yield(format) : format.chomp("\n")
        end
      end
    end
 
    #
    # Task methods
    #
    
    # Instantiates the specifed task with config (if provided).  The task
    # class is determined by task_class.
    #
    #   t = app.task('tap/file_task')
    #   t.class             # => Tap::FileTask
    #   t.name              # => 'tap/file_task'
    #
    #   app.map = {"mapped-task" => "Tap::FileTask"}
    #   t = app.task('mapped-task-1.0', :key => 'value')
    #   t.class             # => Tap::FileTask
    #   t.name              # => "mapped-task-1.0"
    #   t.config[:key]      # => 'value'
    #
    # A new task is instantiated for each call to task; tasks may share the 
    # same name.  
    def task(task_name, config={}, &block)
      task_class(task_name).new(task_name, config, &block) 
    end
    
    # Looks up the specifed task class.  Names are mapped to task classes 
    # using task_class_name.
    #
    #   t_class = app.task_class('tap/file_task')
    #   t_class             # => Tap::FileTask
    #
    #   app.map = {"mapped-task" => "Tap::FileTask"}
    #   t_class = app.task_class('mapped-task-1.0')
    #   t_class             # => Tap::FileTask
    #
    # Notes:
    # - The task class will be auto-loaded using Dependencies, if needed.
    # - A LookupError is raised if the task class cannot be found.
    def task_class(task_name)
      lookup_const task_class_name(task_name) do
        raise LookupError.new("unknown task '#{task_name}'")
      end
    end
    
    # Returns the class name of the specified task.  If the task 
    # descriptor is a string, the class name is the de-versioned, 
    # descriptor, or the class name as specified in map by the 
    # de-versioned descriptor.  
    #
    #   app.map = {"mapped-task" => "Tap::FileTask"}
    #   app.task_class_name('some/task_class')   # => "some/task_class" 
    #   app.task_class_name('mapped-task-1.0')   # => "Tap::FileTask"
    #
    # If td is a type of Tap::Support::Framework, then task_class_name 
    # returns td.class.to_s
    #
    #   t1 = Task.new
    #   app.task_class_name(t1)                   # => "Tap::Task"
    #
    #   t2 = Object.new.extend Tap::Support::Framework
    #   app.task_class_name(t2)                   # => "Object"
    #
    def task_class_name(td)
      case td
      when Support::Framework then td.class.to_s
      else
        # de-version and resolve using map
        name, version = deversion(td.to_s)
        map.has_key?(name) ? map[name].to_s : name
      end
    end
    
    # Iteratively passes the block the configuration templates for the specified file.
    # Ultimately these templates specify configurations for tasks, as well batched tasks,
    # linked to to self.  If no block is specified, each_config_template collects the
    # templates and returns them as an array.
    #
    # To make templates, the contents of the file are processed using ERB, then loaded 
    # as YAML. ERB for the config files is evaluated in a binding that contains  
    # references to self (app) and the input filepath.
    #
    #   # [simple.yml] 
    #   #  key: value
    #
    #   app.each_config_template("simple.yml")  # => [{"key" => "value"}]
    #
    #   # [erb.yml] 
    #   #  app: <%= app.object_id %>
    #   #  filepath: <%= filepath %>
    #
    #   app.each_config_template("erb.yml")  # => [{"app" => app.object_id, "filepath" => "erb.yml"}]
    #
    # Batched tasks can be specified by providing an array of hashes.  
    #
    #   # [batched_with_erb.yml] 
    #   #  - key: <%= 1 %>
    #   #  - key: <%= 1 + 1 %>
    #
    #   app.each_config_template("batched_with_erb.yml")  # => [{"key" => 1}, {"key" => 2}]
    #
    # If no config templates can be loaded (as when the filepath does not exist, or  
    # the file is empty), each_config_template passes the block a single empty template.  
    def each_config_template(filepath) # :yields: template
      unless block_given?
        templates = []
        each_config_template(filepath) {|template| templates << template}
        return templates
      end
    
      if filepath == nil
        yield({}) 
      else
        templates = if !File.exists?(filepath) || File.directory?(filepath)
          nil
        else
          # create the reference to app for templating
          app = self
          input = ERB.new(File.read(filepath)).result(binding)
          YAML.load(input)
        end
        
        case templates
        when Array 
          templates.each do |template|
            yield(template)
          end
        when Hash
          yield(templates) 
        else
          yield({})
        end 
      end
    end
    
    # Returns the configuration filepath for the specified task name,
    # File.join(app['config'], task_name + ".yml"). Returns nil if 
    # task_name==nil.
    def config_filepath(task_name)
      task_name == nil ? nil : filepath('config', task_name + ".yml")
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

    # Sets state = State::READY unless the app has a run_thread 
    # (ie the app is running).  Returns self.
    def ready
      synchronize do 
        self.state = State::READY if self.run_thread == nil
        self
      end
    end

    # Runs the methods in the queue in which they were enqued. Run exists when there
    # are no more enqued methods.  Run returns self.  An app can only run on one thread 
    # at a time.  If run is called when self is already running, run returns immediately.
    #
    # === The Run Cycle
    # During run, each method is executed sequentially on the current thread unless 
    # m.multithread == true.  In this case run switches into a multithreaded mode and 
    # launches up to n execution threads (where n is options.max_threads or 
    # DEFAULT_MAX_THREADS) each of which can run a multithreaded method.  
    #
    # These threads will run methods until a non-multithreaded method reaches the top 
    # of the queue.  At that point, run waits for the multithreaded methods to complete, 
    # and then switches back into the sequential mode.  Run never executes multithreaded 
    # and non-multithreaded methods at the same time.
    #
    # Run checks the state of self before executing a method.  If the state is changed
    # to State::STOP, then no more methods will be executed (but currently running methods
    # will continute to completion).  If the state is changed to State::TERMINATE then
    # no more methods will be executed and currently running methods will be discontinued
    # as described below.
    #
    # When a series of multithreaded methods are stopped or terminated mid-execution,
    # several methods may be waiting for a free execution thread.  These are requeued.
    #
    # === Error Handling and Termination
    # When unhandled errors arise during run, run enters a termination (rescue) 
    # routine.  During termination a TerminationError is raised in each executing 
    # method so that the method exits or begins executing its internal error handling 
    # code (perhaps performing rollbacks).
    #
    # The TerminationError is ONLY raised when the method calls Task::Base#check_terminate
    # This method is available to all Task::Base objects, but obviously is NOT available
    # to Executable methods generated by _method.  These methods need to check the state
    # of app themselves; otherwise they will continue on to completion even when app
    # is in State::TERMINATE.
    #
    #   # this task will loop until app.terminate
    #   Task.new {|task|  while(true) task.check_terminate end }
    #
    #   # this task will NEVER terminate
    #   Task.new {|task|  while(true) end; task.check_terminate }
    #
    # Additional errors that arise during termination are collected and packaged 
    # with the orignal error into a RunError.  By default all errors are logged
    # and run exits.  If debug? == true, then the RunError will be raised for further 
    # handling.
    #
    # Note: the method that caused the original unhandled error is no longer executing 
    # when termination begins and thus will not recieve a TerminationError.  
    def run
      synchronize do
        return self unless self.ready.state == State::READY

        self.run_thread = Thread.current
        self.state = State::RUN
      end
      
      # generate threading variables
      max_threads = options.max_threads || DEFAULT_MAX_THREADS
      self.thread_queue = max_threads > 0 ? Queue.new : nil
      
      # TODO: log starting run
      begin 
        execution_loop do
          break if block_given? && yield(self) 
          
          # if no tasks were in the queue 
          # then clear the threads and 
          # check for tasks again
          if queue.empty?
            clear_threads 
            # break -- no executable task was found
            break if queue.empty?
          end
          
          m, inputs = queue.deq
          
          if thread_queue && m.multithread
            # TODO: log enqueuing task to thread
            
            # generate threads as needed and allowed
            # to execute the threads in the thread queue
            start_thread if threads.size < max_threads 

            # NOTE: the producer-consumer relationship of execution
            # threads and the thread_queue means that tasks will sit
            # waiting until an execution thread opens up.  in the most
            # extreme case all executing tasks and all tasks in the 
            # task_queue could be the same task, each with different
            # inputs.  this deviates from the idea of batch processing,
            # but should be rare and not at all fatal given execute
            # synchronization.  
            thread_queue.enq [m, inputs]
          
          else
            # TODO: log execute task
            
            # wait for threads to complete
            # before executing the main thread
            clear_threads
            execute(m, inputs)
          end
        end
        
        # if the run loop exited due to a STOP state,
        # tasks may still be in the thread queue and/or
        # running.  be sure these are cleared
        clear_thread_queue 
        clear_threads 

      rescue
        # when an error is generated, be sure to terminate
        # all threads so they can clean up after themselves.
        # clear the thread queue first so no more tasks are
        # executed. collect any errors that arise during
        # termination. 
        clear_thread_queue
        errors =  [$!] + clear_threads(false)
        errors.delete_if {|error|  error.kind_of?(TerminateError) }
        
        # handle the errors accordingly
        case
        when debug?
          raise Tap::Support::RunError.new(errors)
        else
          errors.each_with_index do |err, index|
            log("RunError [#{index}] #{err.class}", err.message)
          end
        end
      ensure
      
        # reset run variables
        self.thread_queue = nil
        
        synchronize do
          self.run_thread = nil
          self.state = State::READY
        end
      end
      
      # TODO: log run complete
      self
    end
    
    # Signals a running application to stop executing tasks in the 
    # queue by setting state = State::STOP.  Currently executing 
    # tasks will continue their execution uninterrupted.
    #
    # Does nothing unless state is State::RUN.
    def stop
      synchronize do
        self.state = State::STOP if self.state == State::RUN
        self
      end
    end

    # Signals a running application to terminate executing tasks 
    # by setting state = State::TERMINATE.  When running tasks
    # reach a termination check, the task raises a TerminationError,
    # thus allowing executing tasks to invoke their specific 
    # error handling code, perhaps performing rollbacks.
    #
    # Termination checks can be manually specified in a task
    # using the check_terminate method (see Tap::Task#check_terminate).
    # Termination checks automatically occur before each task execution.
    #
    # Does nothing if state == State::READY.
    def terminate
      synchronize do
        self.state = State::TERMINATE unless self.state == State::READY
        self
      end
    end
    
    # Returns an information string for the App.  
    #
    #   App.instance.info   # => 'state: 0 (READY) queue: 0 thread_queue: 0 threads: 0 results: 0'
    #
    # Provided information:
    #
    # state:: the integer and string values of self.state
    # queue:: the number of methods currently in the queue
    # thread_queue:: number of objects in the thread queue, waiting
    #                to be run on an execution thread (methods, and 
    #                perhaps nils to signal threads to clear)
    # threads:: the number of execution threads
    # results:: the total number of results in aggregator
    def info
      synchronize do
        "state: #{state} (#{State.state_str(state)}) queue: #{queue.size} thread_queue: #{thread_queue ? thread_queue.size : 0} threads: #{threads.size} results: #{aggregator.size}"
      end
    end
    
    # Enques the task with the inputs.  If the task is batched, then each 
    # task in task.batch will be enqued with the inputs.  Returns task.
    #
    # An Executable may provided instead of a task.
    def enq(task, *inputs)
      case task
      when Tap::Task, Tap::Workflow
        raise "not assigned to enqueing app: #{task}" unless task.app == self
        task.enq(*inputs)
      when Support::Executable
        queue.enq(task, inputs)
      else
        raise "Not a Task or Executable: #{task}"
      end
      task
    end

    # Method enque.  Enques the specified method from object with the inputs.
    # Returns the enqued method.
    def mq(object, method_name, *inputs)
      m = object._method(method_name)
      enq(m, *inputs)
    end
    
    # Sets a sequence workflow pattern for the tasks such that the
    # completion of a task enqueues the next task with it's results.
    # Batched tasks will have the pattern set for each task in the 
    # batch.  The current audited results are yielded to the block, 
    # if given, before the next task is enqued.
    #
    # Executables may provided as well as tasks.
    def sequence(*tasks) # :yields: _result
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

    # Sets a fork workflow pattern for the tasks such that each of the
    # targets will be enqueued with the results of the source when the
    # source completes. Batched tasks will have the pattern set for each 
    # task in the batch.  The source audited results are yielded to the 
    # block, if given, before the targets are enqued.
    #
    # Executables may provided as well as tasks.
    def fork(source, *targets) # :yields: _result
      source.on_complete do |_result|
        targets.each do |target| 
          yield(_result) if block_given?
          enq(target, _result)
        end
      end
    end

    # Sets a merge workflow pattern for the tasks such that the results
    # of each source will be enqueued to the target when the source 
    # completes. Batched tasks will have the pattern set for each 
    # task in the batch.  The source audited results are yielded to  
    # the block, if given, before the target is enqued.
    #
    # Executables may provided as well as tasks.
    def merge(target, *sources) # :yields: _result
      sources.each do |source|
        # merging can use the existing audit trails... each distinct 
        # input is getting sent to one place (the target)
        source.on_complete do |_result| 
          yield(_result) if block_given?
          enq(target, _result)
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
    # reconfigure.  If handle_configuration evaluates to false, then reconfigure
    # raises an error.
    def handle_configuation(key, value)
      false
    end
    
    # Sets the state of the application
    attr_writer :state
    
    # The thread on which run is executing tasks.
    attr_accessor :run_thread
    
    # An array containing the execution threads in use by run.  
    attr_accessor :threads
    
    # A Queue containing multithread tasks waiting to be run 
    # on the execution threads.  Nil if options.max_threads= 0
    attr_accessor :thread_queue
    
    private

    def execution_loop
      while true
        case state
        when State::STOP
          break
        when State::TERMINATE
          # if an execution thread handles the termination error, 
          # then the thread may end up here -- terminated but still 
          # running.  Raise another termination error to enter the 
          # termination (rescue) code.
          raise TerminateError.new
        end
   
        yield
      end
    end

    def clear_thread_queue
      return unless thread_queue
      
      # clear the queue and enque the thread complete
      # signals, so that the thread will exit normally
      dequeued = []
      while !thread_queue.empty?
        dequeued << thread_queue.deq
      end

      # add dequeued tasks back, in order, to the task 
      # queue so no tasks get lost due to the stop
      #
      # BUG: this will result in an already-newly-queued 
      # task being promoted along with it's inputs
      dequeued.reverse_each do |task, inputs|
        # TODO: log about not executing
        queue.unshift(task, inputs) unless task.nil?
      end
    end
    
    def clear_threads(raise_errors=true)
      threads.synchronize do
        errors = []
        return errors if threads.empty?
      
        # clears threads gracefully by enqueuing nils, to break
        # the threads out of their loops, then waiting for the
        # threads to work through the queue to the nils
        #
        threads.size.times { thread_queue.enq nil }
        while true
          # TODO -- add a time out?
          
          threads.dup.each do |thread|
            next if thread.alive?
            threads.delete(thread)
            error = thread["error"]
            
            next if error.nil?
            raise error if raise_errors
            
            errors << error
          end

          break if threads.empty?
          Thread.pass
        end
      
        errors
      end
    end
    
    def start_thread
      threads.synchronize do
        # start a new thread and add it to threads.
        # threads simply loop and wait for a task to 
        # be queued.  the thread will block until a 
        # task is available (due to thread_queue.deq)
        #
        # TODO -- track thread index like?
        #  thread["index"] = threads.length
        threads << Thread.new do 
          # TODO - log thread start
        
          begin
            execution_loop do
              m, inputs = thread_queue.deq
              break if m.nil?
            
              # TODO: log execute task on thread #
              execute(m, inputs)
            end
          rescue
            # an unhandled error should immediately
            # terminate all threads
            terminate
            Thread.current["error"] = $!
          end
        end
      end
    end

    # LookupErrors are raised for errors during dependency lookup
    class LookupError < RuntimeError 
    end

    # TerminateErrors are raised to kill executing tasks when terminate 
    # is called on an running App.  They are handled by the run rescue code.
    class TerminateError < RuntimeError 
    end
  end
end