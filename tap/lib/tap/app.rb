require 'logger'
require 'tap/app/api'
require 'tap/app/node'
require 'tap/app/state'
require 'tap/app/stack'
require 'tap/app/queue'
require 'tap/env'

module Tap
  
  # App coordinates the setup and execution of workflows.
  #
  # == Workflows
  #
  # Workflows are composed of nodes and joins. Each node specifies zero or
  # more joins to receive it's output while joins are used to enque or execute
  # other nodes.  As an analogy, nodes can be thought of as command line
  # executables, joins as redirection operators (ex pipe '|'), and app as a
  # shell coordinating execution.
  #
  # Apps provide a dsl to build workflows out of blocks.  This dsl is often
  # the quickest way to sketch out a bit of functionality.  For example:
  #
  #   # % cat [file] | sort
  #
  #   app = Tap::App.new
  #   cat  = app.node {|file| File.read(file) }
  #   sort = app.node {|str| str.split("\n").sort }
  #   cat.on_complete {|res| app.enq(sort, res) }
  #
  # At this point there is nothing to receive the sort output, so running this
  # workflow will not produce any output.  Shells are setup to print dangling
  # outputs to the terminal; similarly apps define default joins to handle the
  # output of unjoined nodes.
  #                       
  #   results = []
  #   app.on_complete {|result| results << result }
  #
  #   File.open("example.txt", "w") do |io|
  #     io.puts "a"
  #     io.puts "c"
  #     io.puts "b"
  #   end
  #
  #   app.enq(cat, "example.txt")
  #   app.run
  #   results          # => [["a", "b", "c"]]
  #
  # The app could have been defined to print the results, but here everything
  # is being kept in-code for illustration.  Note that objects are being
  # passed between the nodes; the file contents (a string) are passed from cat
  # to sort, then sort passes its result (an array) to the on_complete block.
  #
  # Multiple joins and arbitrarily complex joins may defined for a node.  Lets
  # add another join to reverse-sort the output of cat:
  #
  #   rsort = app.node {|str| str.split("\n").sort.reverse }
  #   cat.on_complete  {|res| app.enq(rsort, res) }
  #
  #   results.clear
  #   app.enq(cat, "example.txt")
  #   app.run
  #   results          # => [["a", "b", "c"], ["c", "b", "a"]]
  #                      
  # Now the output of cat is directed at both sort and rsort, resulting in
  # both a forward and reversed array.
  #
  # === Middleware
  #
  # Apps allow middleware to wrap the execution of each node.  Middleware is
  # useful to track the progress of a workflow. A simple auditor looks like
  # this:
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
  #       audit << [node, inputs]
  #       stack.call(node, inputs)
  #     end
  #   end
  #
  #   auditor = app.use AuditMiddleware
  #
  #   app.enq(cat, "example.txt")
  #   app.run
  #
  #   auditor.audit                  
  #   # => [
  #   # [cat, ["example.txt"]],
  #   # [sort, ["a\nc\nb\n"]],
  #   # [rsort, ["a\nc\nb\n"]]
  #   # ]
  #                     
  # Middleware can be nested with multiple calls to use.
  #
  # === Ready, Run, Stop, Terminate
  #
  # Apps have four states.  When ready, an app does not execute nodes.  New
  # nodes push onto the queue and wait until an app is run.
  #
  #   runlist = []
  #   node = app.node { runlist << "node" }
  #   app.enq(node)
  #
  #   runlist          # => []
  #   app.queue.to_a   # => [[node, []]]
  #   app.state        # => App::State::READY
  #
  # Apps run by shifting (node, input) pairs off the queue.  An app will
  # continue running until the queue is empty, which can be a while if joins
  # actively push new nodes onto the queue.
  #
  #   app.run
  #   runlist          # => ["node"]
  #   app.queue.to_a   # => []
  #
  # Stopping an app prevents new nodes from being shifted off the queue; the
  # currently executing node runs to completion and then the app stops.
  #
  #   sleeper = app.node { sleep 1; runlist << "sleeper" }
  #   app.enq(node)
  #   app.enq(sleeper)
  #   app.enq(node)
  #
  #   runlist.clear
  #   app.queue.to_a   # => [[node, []], [sleeper, []], [node, []]]
  #
  #   a = Thread.new { app.run }
  #   Thread.new do 
  #     Thread.pass while runlist.empty?
  #     app.stop
  #     a.join
  #   end.join
  #
  #   runlist          # => ["node", "sleeper"]
  #   app.queue.to_a   # => [[node, []]]
  #
  # The app can be re-started to complete a run.
  #
  #   app.run
  #   runlist          # => ["node", "sleeper", "node"]
  #   app.queue.to_a   # => []
  #
  # Termination is the same as stopping from the perspective of the app; the
  # current node runs to completion and then the app stops.  The difference is
  # from the perspective of the node; long-running nodes can set breakpoints
  # to check for termination and, in that case, raise a TerminateError (see
  # the check_terminate method).
  #
  # A TerminateError is treated as a normal exit; apps rescue them and
  # re-queue the executing node.
  #
  #   terminator = app.node do
  #     sleep 1
  #     app.check_terminate
  #     runlist << "terminator"
  #   end
  #   app.enq(node)
  #   app.enq(terminator)
  #   app.enq(node)
  #
  #   runlist.clear
  #   app.queue.to_a   # => [[node, []], [terminator, []], [node, []]]
  #
  #   a = Thread.new { app.run }
  #   Thread.new do 
  #     Thread.pass while runlist.empty?
  #     app.terminate
  #     a.join
  #   end.join
  #
  #   runlist          # => ["node"]
  #   app.queue.to_a   # => [[terminator, []], [node, []]]
  #
  # As with stop, the app can be restarted to complete a run:
  #
  #   app.run
  #   runlist          # => ["node", "terminator", "node"]
  #   app.queue.to_a   # => []
  #
  # Nodes that never raise a TerminateError will run to completion even when
  # an app is set to terminate.
  class App
    class << self
      # Sets the current app instance
      attr_writer :instance
      
      # Returns the current instance of App.  If no instance has been set,
      # then instance initializes a new App with the default configuration.
      #
      # Instance is used to initialize tasks when no app is specified.  Aside
      # from that, there is nothing magical about instance.
      def instance(auto_initialize=true)
        @instance ||= (auto_initialize ? new : nil)
      end
      
      def setup(dir=Dir.pwd)
        env = Env.setup(dir)
        @instance = new(:env => env)
      end
    end
    
    include Configurable
    include MonitorMixin
    include Signals
    include Node
    
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
    
    # A cache of application objects
    attr_reader :cache
    
    # The application logger
    attr_accessor :logger
    
    config :debug, false, :short => :d, &c.flag      # Flag debugging
    config :force, false, :short => :f, &c.flag      # Force execution at checkpoints
    config :quiet, false, :short => :q, &c.flag      # Suppress logging
    config :verbose, false, :short => :v, &c.flag    # Enables extra logging (overrides quiet
    
    nest :env, Env,                                  # The application environment
      :type => :hidden,
      :writer => false, 
      :init => false
      
    signal nil, :class => Index     # list signals for app
    signal_class :list, Doc         # list available objects
    signal_class :help, Doc         # brings up this help
    signal_class :tutorial, Doc     # brings up a tutorial
    
    signal :enque
    signal_hash :build, 
      :signature => ['set', 'class'], 
      :remainder => 'args'
    signal_hash :use, 
      :method_name => :build, 
      :signature => ['class'], 
      :remainder => 'args'
      
    signal :run                     # run the app
    signal :stop                    # stop the app
    signal :terminate               # terminate the app
    signal :info                    # prints app status
    
    signal_class :exit do           # exits immediately
      def process(args)
        exit(1)
      end
    end
    
    # Creates a new App with the given configuration.  
    def initialize(config={}, options={}, &block)
      super() # monitor
      
      @state = State::READY
      @stack = options[:stack] || Stack.new(self)
      @queue = options[:queue] || Queue.new
      @cache = options[:cache] || {}
      @logger = options[:logger] || DEFAULT_LOGGER
      @joins = []
      on_complete(&block)
      
      self.env = config.delete(:env)
      initialize_config(config)
    end
    
    # Sets the application environment and validates that env can function as
    # an environment.  Env can be set to nil building is impossible without
    # it.
    def env=(env)
      Validation.validate_api(env, [:[]]) unless env.nil?
      @env = env
    end
    
    # True if debug or the global variable $DEBUG is true.
    def debug?
      debug || $DEBUG
    end
    
    # Logs the action and message at the input level (default INFO).  The
    # message is expected to come from a block if left unspecified as nil.
    #
    # Logging is suppressed if quiet is true.
    #
    # ==== Performance Considerations
    #
    # Using a block to generate a message is quicker if logging is off,
    # but slower when logging is on.  However, when messages use a lot of
    # interpolation the log time is dominated by the interpolation; at
    # some point the penalty for using a block is outweighed by the
    # benefit of being able to skip the interpolation.
    #
    # For example:
    #
    #   log(:action, "this is fast")
    #   log(:action) { "and there's not much benefit to the block" }
    #
    #   log(:action, "but a message with #{a}, #{b}, #{c}, and #{d}")
    #   log(:action) { "may be #{best} in a block because you can #{turn} #{it} #{off}" }
    #
    def log(action, msg=nil, level=Logger::INFO)
      if !quiet || verbose
        msg ||= yield
        logger.add(level, msg, action.to_s)
      end
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
    
    # Generates a node from the block and enques. Returns the new node.
    def bq(*inputs, &block) # :yields: *inputs
      node = self.node(&block)
      queue.enq(node, inputs)
      node
    end
    
    # Adds the specified middleware to the stack.
    def use(middleware, *argv)
      synchronize do
        @stack = middleware.new(@stack, *argv)
      end
    end
    
    # Sets the object to the specified variable, unless var is empty.
    # Non-string variables are converted to strings. Returns obj.
    def set(var, obj)
      var = var.to_s
      var = '' if var == 'app'
      cache[var] = obj unless var.empty?
      obj
    end
    
    # Returns the object set to var, or self for empty var.  Non-string
    # variables are converted to strings.
    def obj(var)
      var = var.to_s
      var = '' if var == 'app'
      var.empty? ? self : cache[var]
    end
    
    # Returns the variable for the object.  If the object is not assigned to a
    # variable and auto_assign is true, then the object is set to an unused
    # variable and the new variable is returned.
    def var(obj, auto_assign=false)
      cache.each_pair do |var, object|
        return var if obj == object
      end
      return nil unless auto_assign
      
      index = cache.length
      loop do 
        var = index.to_s
        
        if cache.has_key?(var)
          index += 1
        else
          set(var, obj)
          return var
        end
      end
    end
    
    def call(spec)
      return self unless spec
      
      if spec.kind_of?(String)
        args = Shellwords.shellwords(spec)
        var, sig = args.shift.to_s.split("/")
        
        spec = {
          'var' => var,
          'sig' => sig,
          'args' => args
        }
      end
      
      var = spec['var']
      sig = spec['sig']
      args = spec['args'] || spec
      
      sig ||= (var.nil? && !args.empty? ? 'build' : nil)
      
      object = obj(var)
      if object.respond_to?(:signal)
        object.signal(sig).call(args)
      else
        hint = signal?(var) ? " (did you mean '--//#{var}'?)" : nil
        raise "unknown object: #{var}#{hint}"
      end
    end
    
    def build(spec)
      var = spec['set']
      args = spec['args'] || spec
      klass = spec['class'].to_s.strip
      
      # these checks exist because the server interface 
      # isn't smart enough to do them yet
      raise "no class specified" if klass.empty?
      
      unless klass = env ? env[klass] : Env::Constant.constantize(klass)
        raise "unresolvable constant: #{spec['class'].inspect}"
      end
      
      method = args.kind_of?(Hash) ? :build : :parse!
      obj, args = klass.send(method, args, self)
      set(var, obj)
      
      [obj, args]
    end
    
    def enque(var, *args)
      node = obj(var)
      queue.enq(node, args)
      node
    end
    
    # Returns an array of middlware in use by self.
    def middleware
      middleware = []
      
      synchronize do
        current = stack
        until current.kind_of?(Stack)
          middleware << current
          current = current.stack
        end
      end
      
      middleware
    end
    
    # Clears the cache, the queue, and resets the stack so that no middleware
    # is used.  Reset raises an error unless state == State::READY.
    def reset
      synchronize do
        unless state == State::READY
          raise "cannot reset unless READY"
        end
        
        @stack = Stack.new(self)
        cache.clear
        queue.clear
      end
    end
    
    # Dispatches node to the application stack with the inputs.
    def execute(node, *inputs)
      dispatch(node, inputs)
    end
    
    # Dispatch does the following in order:
    #
    # - call stack with the node and inputs
    # - call the node joins (if node responds to joins)
    #
    # Dispatch returns the node result.
    #
    # ==== Default Joins
    #
    # The joins for self will be called if node.joins returns an empty array.
    # These 'default' joins will not be called if node.joins returns false or
    # nil.  Nodes that do not respond to joins will not call the default
    # joins either.
    #
    def dispatch(node, inputs=[])
      result = stack.call(node, inputs)
      
      if node.respond_to?(:joins)
        if joins = node.joins

          if joins.empty?
            joins = self.joins
          end
        
          joins.each do |join|
            join.call(result)
          end
        end
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
      
      begin
        while state == State::RUN
          break unless entry = queue.deq
          dispatch(*entry)
        end
      rescue(TerminateError)
        # gracefully fail for termination errors
        queue.unshift(*entry)
      ensure
        synchronize { @state = State::READY }
      end
      
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
        yield if block_given?
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
    # ==== Notes
    #
    # Platforms that use {Syck}[http://whytheluckystiff.net/syck/] (ex MRI)
    # require a fix because Syck misformats certain dumps, such that they
    # cannot be reloaded (even by Syck).  Specifically:
    #
    #   &id001 !ruby/object:Tap::Task ?
    #
    # should be:
    #
    #   ? &id001 !ruby/object:Tap::Task
    #
    # Dump fixes this error and, in addition, removes Thread and Proc dumps
    # because they can't be allocated on load.
    def dump(target=$stdout, options={})
      synchronize do
        options = {
          :date_format => '%Y-%m-%d %H:%M:%S',
          :date => true,
          :info => true
        }.merge(options)
        
        # print basic headers
        target.puts "# date: #{Time.now.strftime(options[:date_format])}" if options[:date]
        target.puts "# info: #{info}" if options[:info]
        
        # dump yaml, fixing as necessary
        yaml = YAML.dump(self)
        yaml.gsub!(/\&(.*!ruby\/object:.*?)\s*\?/) {"? &#{$1} " } if YAML.const_defined?(:Syck)
        yaml.gsub!(/!ruby\/object:(Thread|Proc) \{\}/, '')
        target << yaml
      end
      
      target
    end
    
    def to_schema
      objects = cache.values
      
      signals = queue.to_a.collect do |(node, args)|
        objects << node
        {'sig' => 'enque', 'args' => [var(node)] + args}
      end
      
      objects.concat middleware
      
      specs = {}
      master_order = []
      objects.uniq.collect do |obj|
        order = trace(obj, specs)
        master_order.concat(order)
      end
      
      master_order.uniq.collect do |obj|
        specs[obj]
      end + signals
    end
    
    private
    
    BUILD_KEYS = %w{set type class spec}
    
    # Traces each object backwards and forwards for node, joins, etc. and
    # adds each to specs as needed.  The trace determines and returns the
    # order in which these specs must be initialized to make sense.  
    # Circular traces are detected.
    #
    # Note that order is not provided for the first call; order problems
    # are trace-specific.  For example (a -> b means 'a' references or
    # requires 'b' so read backwards for order):
    #
    #   # Circular trace [a,c,b,a]
    #   a -> b -> c -> a
    #
    #   # Not a problem [[b,a], [b,c]] => [b,a,c]
    #   a -> b
    #   c -> b
    # 
    # As in the example, a consistent master order may be compiled with
    # flatten.uniq.
    #
    def trace(obj, specs, order=[]) # :nodoc:
      if specs.has_key?(obj)
        return order
      end
      
      spec = {}
      if var = self.var(obj)
        spec['set'] = var
      end
      
      klass = obj.class
      if env
        const_name = klass.to_s
        klass = env.constants.unseek(true) do |const|
          const_name == const.const_name
        end
      end
      spec['class'] = klass.to_s
      
      obj_spec = obj.to_spec
      if BUILD_KEYS.find {|key| obj_spec.has_key?(key) }
        spec['spec'] = obj_spec
      else
        spec.merge!(obj_spec)
      end
      
      specs[obj] = spec
      
      refs, brefs = obj.associations
      
      # references to other objects
      # (these must exist prior to obj)
      refs.each do |ref|
        trace(ref, specs, order)
      end if refs
      
      order << obj
      
      # back-references to objects that refer to obj
      # (ie obj must exist before the bref)
      brefs.each do |bref|
        trace(bref, specs, order)
      end if brefs
      
      order
    end
    
    # TerminateErrors are raised to kill executing nodes when terminate is 
    # called on an running App.  They are handled by the run rescue code.
    class TerminateError < RuntimeError
    end
  end
end