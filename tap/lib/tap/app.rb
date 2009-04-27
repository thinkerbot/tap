require 'logger'
require 'configurable'
require 'tap/app/state'
require 'tap/app/stack'
require 'tap/app/queue'

module Tap
  
  # App coordinates the setup and running of tasks, and provides an interface 
  # to the application directory structure. All tasks have an app (by default
  # App.instance) through which they access application-wide resources like
  # the logger, executable queue, and dependencies.
  #
  # === Running Tasks
  #
  # Tasks may be enqued and run by an App:
  #
  #   app = Tap::App.new
  #   t = app.task {|task, *inputs| inputs }
  #   t.enq('a', 'b', 'c')
  #   t.enq(1)
  #   t.enq(2)
  #   t.enq(3)
  #
  #   results = []
  #   app.on_complete {|result| results << result }
  #
  #   app.run
  #   results                        # => [['a', 'b', 'c'], [1], [2], [3]]
  #
  # To construct a workflow, set joins for individual tasks.  When a task
  # completes, it calls its join with its result.  If no join is set, the
  # result goes to the default join for the app (ie the on_complete block
  # as set above).  Here is a simple sequence:
  #
  #   t0 = app.task {|task| "a" }
  #   t1 = app.task {|task, input| "#{input}.b" }
  #   t2 = app.task {|task, input| "#{input}.c"}
  #
  #   t0.sequence(t1,t2)
  #   t0.enq
  #
  #   results.clear
  #   app.run
  #   results                        # => ["a.b.c"]
  #
  # Apps allow middleware to help track the progress of a workflow, and to
  # implement other functionality that needs to wrap each task.  Middleware
  # is initialized with the application stack and should call the stack
  # within it's call method.
  #
  #   class AuditMiddleware
  #     attr_reader :stack, :audit
  #
  #     def initialize(stack)
  #       @stack = stack
  #       @audit = []
  #     end
  #
  #     def call(node, inputs=[])
  #       audit << node
  #       stack.call(node, inputs)
  #     end
  #   end
  #
  #   auditor = app.use AuditMiddleware
  #
  #   t0.enq
  #   t2.enq("x")
  #   t1.enq("y")
  #
  #   results.clear
  #   app.run
  #   results                        # => ["a.b.c", "x.c", "y.b.c"]
  #   auditor.audit                  
  #   # => [
  #   # t0, t1, t2, 
  #   # t2,
  #   # t1, t2
  #   # ]
  # 
  # === Dependencies
  #
  # Tasks allow the construction of dependency-based workflows.  A task only
  # executes after its dependencies have been resolved (ie executed).
  #
  #   runlist = []
  #   t0 = app.task {|task| runlist << task }
  #   t1 = app.task {|task| runlist << task }
  #
  #   t0.depends_on(t1)
  #   t0.enq
  #
  #   app.run
  #   runlist                        # => [t1, t0]
  #
  # Dependencies are resolved every time a task executes; individual
  # dependencies can implement single-execution if desired.
  class App
    class << self
      # Sets the current app instance
      attr_writer :instance
      
      # Returns the current instance of App.  If no instance has been set,
      # then instance initializes a new App with the default configuration. 
      def instance
        @instance ||= App.new
      end
    end
    
    include Configurable
    include MonitorMixin
    
    # The default App logger writes to $stderr at level INFO.
    DEFAULT_LOGGER = Logger.new($stderr)
    DEFAULT_LOGGER.level = Logger::INFO
    DEFAULT_LOGGER.formatter = lambda do |severity, time, progname, msg|
      "  %s[%s] %18s %s\n" % [severity[0,1], time.strftime('%H:%M:%S') , progname || '--' , msg]
    end
    
    # The state of the application (see App::State)
    attr_reader :state
    
    # The application call stack for executing nodes
    attr_reader :stack
    
    # The application queue
    attr_reader :queue
    
    # A cache of application-specific data.  Internally used to store class
    # instances of tasks.  Not recommended for casual use.
    attr_reader :cache
    
    # The default_join for nodes that have no join set
    attr_accessor :default_join
    
    # The application logger
    attr_reader :logger
    
    config :debug, false, &c.flag                 # Flag debugging
    config :force, false, &c.flag                 # Force execution at checkpoints
    config :quiet, false, &c.flag                 # Suppress logging
    config :verbose, false, &c.flag               # Enables extra logging (overrides quiet)
    
    # Creates a new App with the given configuration.  
    def initialize(config={}, options={}, &block)
      super() # monitor
      
      @state = State::READY
      @stack = options[:stack] || Stack.new
      @queue = options[:queue] || Queue.new
      @cache = options[:cache] || {}
      @trace = []
      on_complete(&block)
      
      initialize_config(config)
      self.logger = options[:logger] || DEFAULT_LOGGER
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
    
    # Returns a new node that executes block on call.
    def node(&block) # :yields: *inputs
      Node.intern(&block)
    end
    
    # Enques the node with the inputs.  Returns the node.
    def enq(node, *inputs)
      queue.enq(node, inputs)
      node
    end
    
    # Generates a Node from the block and enques. Returns the new node.
    def bq(*inputs, &block) # :yields: *inputs
      node = self.node(&block)
      queue.enq(node, inputs)
      node
    end
    
    # Adds the specified middleware to the stack.
    def use(middleware)
      @stack = middleware.new(@stack)
    end
    
    # Dispatches each dependency of node.  A block can be given to do something
    # else with the nodes (ex: reset single-execution dependencies).  Resolve
    # will recursively yield dependencies if specified.
    #
    # Resolve raises an error for circular dependencies.
    def resolve(node, recursive=false, &block)
      node.dependencies.each do |dependency|
        if @trace.include?(dependency)
          @trace.push dependency
          raise DependencyError.new(@trace)
        end

        # mark the results at the index to prevent
        # infinite loops with circular dependencies
        @trace.push dependency
        
        if recursive
          resolve(dependency, recursive, &block)
        end
        
        if block_given?
          yield(dependency)
        else
          dispatch(dependency)
        end
        
        @trace.pop
      end
    end
    
    # Dispatches node to the application stack with the inputs.
    def execute(node, *inputs)
      dispatch(node, inputs)
    end
    
    # Dispatch sends the node into the application stack with the inputs.
    # Dispatch does the following in order:
    #
    # - resolve node dependencies using resolve_dependencies
    # - call stack with the node and inputs
    # - call the node join, if set, or the default_join with the results
    #
    # Dispatch returns the node result.
    def dispatch(node, inputs=[])
      resolve(node)
      result = stack.call(node, inputs)

      if join = (node.join || default_join)
        join.call(result)
      end
      result
    end
    
    # Sequentially dispatches each enqued (node, inputs) pair to the
    # application stack.  A run continues until the queue is empty.  Returns
    # self.
    #
    # ==== Run State
    #
    # Run checks the state of self before dispatching a node.  If the state
    # changes from State::RUN, the following behaviors result:
    # 
    # State::STOP:: No more nodes will be dispatched; the current node will
    #               continute to completion.
    # State::TERMINATE:: No more nodes will be dispatched and the currently
    #                    running node will be discontinued as described in
    #                    terminate.
    #
    # Calls to run when the state is not State::READY do nothing and
    # return immediately.
    def run
      synchronize do
        return self unless state == State::READY
        @state = State::RUN
      end

      # TODO: log starting run
      begin
        until queue.empty? || state != State::RUN
          dispatch(*queue.deq)
        end
      rescue(TerminateError)
        # gracefully fail for termination errors
      rescue(Exception)
        # handle other errors accordingly
        raise if debug?
        log($!.class, $!.message)
      ensure
        synchronize { @state = State::READY }
      end
      
      # TODO: log run complete
      self
    end
    
    # Signals a running app to stop dispatching nodes to the application stack
    # by setting state = State::STOP.  The node currently in the stack will
    # will continue to completion.
    #
    # Does nothing unless state is State::RUN.
    def stop
      synchronize { @state = State::STOP if state == State::RUN }
      self
    end

    # Signals a running application to terminate execution by setting 
    # state = State::TERMINATE.  In this state, calls to check_terminate
    # will raise a TerminateError.  Run considers TerminateErrors a normal
    # exit and rescues them quietly.
    #
    # Nodes can set breakpoints that call check_terminate to invoke
    # node-specific termination.  If a node never calls check_terminate, then
    # it will continue to completion and terminate is functionally the same
    # as stop.
    #
    # Does nothing if state == State::READY.
    def terminate
      synchronize { @state = State::TERMINATE unless state == State::READY }
      self
    end
    
    # Raises a TerminateError if state == State::TERMINATE.  Nodes should call
    # check_terminate to provide breakpoints in long-running processes.
    def check_terminate
      if state == App::State::TERMINATE
        raise App::TerminateError.new
      end
    end
    
    # Returns an information string for the App.  
    #
    #   App.instance.info   # => 'state: 0 (READY) queue: 0'
    #
    def info
      "state: #{state} (#{State.state_str(state)}) queue: #{queue.size}"
    end
    
    # Dumps self to the target as YAML.
    #
    # === Implementation Notes
    #
    # Platforms that use syck (ex MRI) require a fix because syck misformats
    # certain dumps, such that they cannot be reloaded (even by syck).
    # Specifically:
    #
    #   &id001 !ruby/object:Tap::Task ?
    #
    # should be:
    #
    #   ? &id001 !ruby/object:Tap::Task
    #
    # In addition, dump removes Thread and Proc dumps because they can't be
    # allocated on load
    def dump(target=$stdout, options={})
      synchronize do
        raise "cannot dump unless READY" unless state == State::READY
        
        options = {
          :date_format => '%Y-%m-%d %H:%M:%S',
          :date => true,
          :info => true
        }.merge(options)
        
        # print basic headers
        target.puts "# date: #{Time.now.strftime(options[:date_format])}" if options[:date]
        target.puts "# info: #{info}" if options[:info]
        
        # # print load paths and requires
        # target.puts "# load paths"
        # target.puts $:.to_yaml
        # 
        # target.puts "# requires"
        # target.puts $".to_yaml
        
        # dump yaml, fixing as necessary
        yaml = YAML.dump(self)
        yaml.gsub!(/\&(.*!ruby\/object:.*?)\s*\?/) {"? &#{$1} " } if YAML.const_defined?(:Syck)
        yaml.gsub!(/!ruby\/object:(Thread|Proc) \{\}/, '')
        target << yaml
      end
      
      target
    end
    
    # Sets the block to receive the audited result of tasks with no join
    # (ie the block is set as default_join).
    def on_complete(&block) # :yields: _result
      self.default_join = block
      self
    end
    
    protected
    
    # TerminateErrors are raised to kill executing tasks when terminate is 
    # called on an running App.  They are handled by the run rescue code.
    class TerminateError < RuntimeError 
    end
    
    # Raised when Dependencies#resolve detects a circular dependency.
    class DependencyError < StandardError
      def initialize(trace)
        super "circular dependency: [#{trace.join(', ')}]"
      end
    end
  end
end