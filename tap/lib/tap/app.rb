require 'logger'
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
  #   app = App.instance
  #
  #   t = Task.intern {|task, *inputs| inputs }
  #   t.enq('a', 'b', 'c')
  #   t.enq(1)
  #   t.enq(2)
  #   t.enq(3)
  #
  #   app.run
  #   app.results(t)                 # => [['a', 'b', 'c'], [1], [2], [3]]
  #
  # By default apps simply run tasks and collect the results.  To construct
  # a workflow, set an on_complete block to receive the audited result and
  # enque or execute the next series of tasks.  Here is a simple sequence:
  #
  #   t0 = Task.intern {|task| "0" }
  #   t1 = Task.intern {|task, input| "#{input}:1" }
  #   t2 = Task.intern {|task, input| "#{input}:2"}
  #
  #   t0.on_complete {|_result| t1.enq(_result) }
  #   t1.on_complete {|_result| t2.enq(_result) }
  #   
  #   t0.enq
  #   app.run
  #   app.results(t0, t1)            # => []
  #   app.results(t2)                # => ["0:1:2"]
  #
  # Apps may be assigned an on_complete block as well; the app on_complete
  # block is called when a task has no on_complete block set.  If neither the
  # task nor the app has an on_complete block, the app stores the audit in
  # app.aggregator and makes it available through app.results.  Note how after
  # the sequence, the t0 and t1 results are not in the app (they were handled
  # by the on_complete block).
  #
  # Tracking how inputs evolve through a workflow can be onerous.  To help,
  # Tap audits changes to the inputs.  Audit values are by convention prefixed
  # by an underscore; all on_complete block receive the audited values and not
  # the actual result of a task.  Aggregated audits are available through
  # app._results.
  #
  #   t2.enq("a")
  #   t1.enq("b")
  #   app.run
  #   app.results(t2)                # => ["0:1:2", "a:2", "b:1:2"]
  # 
  #   t0.name = "zero"
  #   t1.name = "one"
  #   t2.name = "two"
  #
  #   trails = app._results(t2).collect do |_result|
  #     _result.dump
  #   end
  #
  #   "\n" + trails.join("\n")
  #   # => %q{
  #   # o-[zero] "0"
  #   # o-[one] "0:1"
  #   # o-[two] "0:1:2"
  #   # 
  #   # o-[] "a"
  #   # o-[two] "a:2"
  #   # 
  #   # o-[] "b"
  #   # o-[one] "b:1"
  #   # o-[two] "b:1:2"
  #   # }
  #
  # See Audit for more details.
  #
  # === Dependencies
  #
  # Tasks allow the construction of dependency-based workflows.  A dependent
  # task only executes after its dependencies have been resolved.
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
  # === Nodes
  #
  # App can enque and run any Node object. Arbitrary methods may be
  # made into Nodes using Object#_method.
  #
  #   array = []
  #
  #   m = array._method(:push)
  #   m.enq(1)
  #   m.enq(2)
  #   m.enq(3)
  #
  #   array.empty?                   # => true
  #   app.run
  #   array                          # => [1, 2, 3]
  #
  class App
    include Configurable
    include MonitorMixin
    
    # The application logger
    attr_reader :logger
    
    # The application queue
    attr_reader :queue
    
    # The state of the application (see App::State)
    attr_reader :state
    
    # The aggregator receives results of executables that have no join.
    attr_accessor :aggregator
    
    config :audit, true, &c.switch                # Signal auditing
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
      
      # Returns a string corresponding to the input state value.  
      # Returns nil for unknown states.
      #
      #   State.state_str(0)        # => 'READY'
      #   State.state_str(12)       # => nil
      def state_str(state)
        constants.inject(nil) {|str, s| const_get(s) == state ? s.to_s : str}
      end
    end
    
    # Creates a new App with the given configuration.  
    def initialize(config={}, logger=DEFAULT_LOGGER, &block)
      super() # monitor
      
      @state = State::READY
      @queue = Queue.new
      on_complete(&block)
      
      initialize_config(config)
      self.logger = logger
    end
    
    # The default App logger writes to $stderr at level INFO.
    DEFAULT_LOGGER = Logger.new($stderr)
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
    
    # Enques the executable with the inputs.  Raises an error if the input is
    # not a Node, or is not assigned to self.  Returns the executable.
    def enq(node, *inputs)
      unless node.kind_of?(Node)
        raise ArgumentError, "not a Node: #{node.inspect}"
      end
      
      queue.enq(node, inputs)
      node
    end
    
    # Generates a Node from the block and enques. Returns the new node.
    def bq(*inputs, &block)
      node = block.extend Node
      queue.enq(node, inputs)
      node
    end
    
    # Sequentially calls execute with the (executable, inputs) pairs in
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
      synchronize do
        return self unless state == State::READY
        @state = State::RUN
      end

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
        synchronize { @state = State::READY }
      end
      
      # TODO: log run complete
      self
    end
    
    # Executes the node with the specified inputs.
    def execute(node, inputs)
      claim(node) do
        node.resolve_dependencies

        sources = []
        inputs.collect! do |input| 
          if input.kind_of?(Audit) 
            sources << input
            input.value
          else
            sources << Audit.new(nil, input)
            input
          end
        end
      
        check_terminate
        _result = Audit.new(node, node.call(*inputs), audit ? sources : nil)
        if join = (node.join || aggregator)
          claim(join) { join.call(_result) }
        end
      
        _result
      end
    end
    
    # Signals a running application to stop executing tasks in the 
    # queue by setting state = State::STOP.  The task currently 
    # executing will continue uninterrupted to completion.
    #
    # Does nothing unless state is State::RUN.
    def stop
      synchronize { @state = State::STOP if state == State::RUN }
      self
    end

    # Signals a running application to terminate execution by setting 
    # state = State::TERMINATE.  In this state, an executing task 
    # will then raise a TerminateError upon check_terminate, thus 
    # allowing the invocation of task-specific termination, perhaps 
    # performing rollbacks. (see check_terminate).
    #
    # Does nothing if state == State::READY.
    def terminate
      synchronize { @state = State::TERMINATE unless state == State::READY }
      self
    end
    
    # Raises a TerminateError if state == State::TERMINATE.
    # check_terminate may be called at any time to provide a 
    # breakpoint in long-running processes.
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
    # (ie the block is set as aggregator).
    def on_complete(&block) # :yields: _result
      self.aggregator = block_given? ? Join.intern(&block) : nil
      self
    end
    
    protected
    
    # claims an object during execution
    def claim(obj) # :nodoc:
      unless obj.app == nil
        raise "not assigned to self: #{obj.inspect}"
      end
      
      begin
        obj.app = self
        yield
      ensure
        obj.app = nil
      end
    end
    
    # TerminateErrors are raised to kill executing tasks when terminate is 
    # called on an running App.  They are handled by the run rescue code.
    class TerminateError < RuntimeError 
    end
  end
end