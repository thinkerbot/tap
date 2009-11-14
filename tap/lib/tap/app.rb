require 'logger'
require 'tap/app/api'
require 'tap/app/node'
require 'tap/app/state'
require 'tap/app/stack'
require 'tap/app/queue'
require 'tap/env'
require 'tap/builder'
require 'tap/parser'

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
  # workflow will not produce any output.  Whereas shells are setup to print
  # dangling outputs to the terminal, apps may define default joins to handle
  # the output of unjoined nodes.
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
  # Instead of printing the results this example aggregates the results into
  # an array.  Note that objects are being passed between the nodes; the file
  # contents (a string) are passed from cat to sort, then sort passes its
  # result (an array) to the on_complete block.  Unlike the command line,
  # objects do not need to be serialized and deserialized to a stream.
  #
  # Moreover, multiple joins and arbitrarily complex joins may defined for a
  # node.  Lets add another join to reverse-sort the output of cat:
  #
  #   rsort = app.node {|str| str.split("\n").sort.reverse }
  #   cat.on_complete  {|res| app.enq(rsort, res) }
  #   cat.joins.length # => 2
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
  # useful to track the progress of a workflow, and may be used to pre- and
  # post-process objects passed among nodes. A simple auditor looks like this:
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
  # Apps run by shifting jobs ([node, input] pairs) off the queue.  An app
  # will continue running until the queue is empty, which can be a while if
  # joins actively push new nodes onto the queue.
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
  # The app can be re-started to complete the run.
  #
  #   app.run
  #   runlist          # => ["node", "sleeper", "node"]
  #   app.queue.to_a   # => []
  #
  # Termination is the same as stopping from the perspective of the app; the
  # current node runs to completion and then the app stops.  The difference is
  # from the perspective of the node; long-running nodes can set breakpoints
  # to check for termination and, in that case, raise a TerminateError.
  # Normally nodes do this by calling the check_terminate method.
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
  #
  # === Application Objects
  #
  # Apps can build and store objects that need persistence for one reason or
  # another.  Application objects allow workflows to be built incrementally
  # from a schema and, once built, to be serialized back into a schema.
  #
  # Use the set and get methods to manually store and retreive application
  # objects:
  #
  #   app = App.new
  #   app.set('a', :A)
  #   app.get('a')       # => :A
  #   app.objects        # => {'a' => :A}
  #
  # The build method constructs and stores objects that implement the
  # application interface (see the API[link:files/doc/API.html] document). As
  # a minimal example, consider this class:
  #
  #   class Resource
  #     class << self
  #       def parse!(argv=ARGV, app=Tap::App.instance)
  #         build({'argv' => argv}, app)
  #       end
  #
  #       def build(spec={}, app=Tap::App.instance)
  #         new(spec['argv'], app)
  #       end
  #     end
  #
  #     attr_reader :argv, :app
  #     def initialize(argv, app)
  #       @argv = argv
  #       @app = app
  #     end
  #
  #     def associations
  #       nil
  #     end
  #
  #     def to_spec
  #       {'argv' => @argv}
  #     end
  #   end
  #
  # Resource instances can be built from an array or a hash using the Resource
  # parse! and build methods, respectively.  The associations and to_spec
  # methods make it so that individual resources can be serialized to a
  # specification hash and rebuilt.
  #
  #   a = Resource.parse!([1, 2, 3], app)
  #   a.argv           # => [1, 2, 3]
  #
  #   b = Resource.build(a.to_spec, app)
  #   b.argv           # => [1, 2, 3]
  #
  # At the application level, these qualities allow resources to be built and
  # serialized through the build and to_schema methods.  Build takes a hash
  # defining these fields:
  #
  #   var     # a variable to identify the object
  #   class   # the class name or identifier, as a string
  #   spec    # the parse! array or the build hash
  #
  # Building a resource looks like this:
  #
  #   app.build('var' => 'a', 'class' => 'Resource', 'spec' => [1, 2, 3])
  #   a = app.get('a')
  #   a.class               # => Resource
  #   a.argv                # => [1, 2, 3]
  #
  # Note that when spec is a hash, and does not require any of the same keys,
  # it can be merged with the build hash.  These both build a resource:
  #
  #   app.build('var' => 'b', 'class' => 'Resource', 'spec' => {'argv' => [4, 5, 6]})
  #   app.build('var' => 'c', 'class' => 'Resource', 'argv' => [7, 8, 9])
  #
  # Serializing the application objects looks like this:
  #
  #   app.to_schema
  #   # => [
  #   # {'var' => 'a', 'class' => 'Resource', 'argv' => [1, 2, 3]},
  #   # {'var' => 'b', 'class' => 'Resource', 'argv' => [4, 5, 6]},
  #   # {'var' => 'c', 'class' => 'Resource', 'argv' => [7, 8, 9]}
  #   # ]
  #
  # Schema are arrays of build hashes; rebuilding each in order will
  # regenerate the objects, and hence the workflow described by the objects.
  # Although it is not apparent in this example, objects will be correctly
  # ordered in the schema to ensure they can be rebuilt (see the
  # API[link:files/doc/API.html] for more details).
  #                          
  # === Signals
  #
  # Apps use signals to create and control application objects from a user
  # interface. Signals are designed to map easily to the command line, urls,
  # and to serialization formats like YAML/JSON, while remaining concise in
  # code.
  #
  # Signals are hashes that define these fields:
  #
  #   obj      # a variable identifying an application object
  #   sig      # the signal name
  #   args     # arguments to the signal
  #
  # The call method receives signals and essentially does the following:
  #
  #   object = app.get(obj)        # lookup an application object by obj
  #   signal = object.signal(sig)  # lookup a signal by sig
  #   signal.call(args)            # call the signal with args
  #
  # An app can itself be signaled when set as an application object. As a
  # result, signals can be used to build objects:
  #
  #   app = App.new
  #   app.set('', app)
  #   app.call(
  #     'obj' => '', 
  #     'sig' => 'build', 
  #     'args' => {
  #       'var' => 'a',
  #       'class' => 'Resource',
  #       'spec' => {'argv' => [1, 2, 3]}
  #     }
  #   )
  #   a = app.get('a')
  #   a.class                    # => Resource
  #   a.argv                     # => [1, 2, 3]
  #
  # By convention an empty string is used to identify an app and apps are
  # constructed so that, at least when args are specified, the default signal
  # is 'build'.  Furthermore the args hash can be merged into the signal hash
  # in the same way a spec can be merged into a build hash.  As a result many
  # resources can be built with very compact signals:
  #
  #   app.call('var' => 'b', 'class' => 'Resource', 'argv' => [4, 5])
  #   b = app.get('b')
  #   b.class                    # => Resource
  #   b.argv                     # => [4, 5]
  #
  # This is ONLY possible for resources whose specs do not use any of the six
  # signal or build keys (obj, sig, args, var, class, spec), and requires the
  # app is set to an empty string in objects.
  #
  # The Tap::Signals module provides a dsl for exposing methods as signals. In
  # the simplest case you simply declare the signal; the signal args will be
  # splat-ed down as the method inputs.
  #
  #   class Resource
  #     include Tap::Signals
  #     signal :length
  #
  #     def length(extra=0)
  #       @argv.length + extra
  #     end
  #   end
  #
  #   a.length                 # => 3
  #   b.length                 # => 2
  #   b.length(1)              # => 3
  #
  #   app.call('obj' => 'a', 'sig' => 'length', 'args' => [])   # => 3
  #   app.call('obj' => 'b', 'sig' => 'length', 'args' => [])   # => 2
  #   app.call('obj' => 'b', 'sig' => 'length', 'args' => [1])  # => 3
  #
  # Signals are a roundabout way of executing methods and should typically not
  # be used in code.  However, signals provide a good way of exposing an API
  # to end-users.  call is the primary method through which user interfaces
  # communicate with apps and application objects.
  #
  class App
    class << self
      # Sets the current app instance
      attr_writer :instance
      
      # Returns the current instance of App.  If no instance has been set,
      # then instance initializes a new App with the default configuration.
      # Instance is used to initialize tasks when no app is specified and
      # exists for convenience only.
      def instance(auto_initialize=true)
        @instance ||= (auto_initialize ? new : nil)
      end
      
      # Sets up and returns App.instance with an Env setup to the specified
      # directory.  This method is used to initialize the app and env as seen
      # by the tap executable.
      def setup(dir=Dir.pwd)
        env = Env.setup(dir)
        @instance = new(:env => env)
      end
      
      def build(spec={}, app=nil)
        config = spec['config'] || {}
        schema = spec['schema'] || []
        
        if spec['self']
          app.reconfigure(config)
        else
          app = new(config)
        end
        
        schema.each do |args|
          app.call(args)
        end
        
        app.gc
        app
      end
    end
    
    include Configurable
    include MonitorMixin
    include Signals
    include Node
    
    # The reserved call keys
    CALL_KEYS = %w{obj sig args}
    
    # The reserved build keys
    BUILD_KEYS = %w{var class spec}
    
    # Reserved call and build keys as a single array
    RESERVED_KEYS = CALL_KEYS + BUILD_KEYS
    
    # The default App logger (writes to $stderr at level INFO)
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
    attr_reader :objects
    
    # The application logger
    attr_accessor :logger
    
    config :debug, false, :short => :d, &c.flag      # Flag debugging
    config :force, false, :short => :f, &c.flag      # Force execution at checkpoints
    config :quiet, false, :short => :q, &c.flag      # Suppress logging
    config :verbose, false, :short => :v, &c.flag    # Enables extra logging (overrides quiet)
    
    config :auto_enque, true, &c.flag
    config :bang, true, &c.flag
    
    nest :env, Env,                                  # The application environment
      :type => :hidden,
      :writer => false, 
      :init => false
      
    # The index signal ('') is constructed to list signals if no arguments are
    # given, and invoke a build otherwise:
    #
    #   --//         # => list signals (like a normal index)
    #   --// a b c   # => build
    #
    # Of course build can be manually specified if desired:
    #
    #   --//build a b c
    #
    signal_class nil, Index do      # list signals for app
      def call(args) # :nodoc:
        # note Build is defined by the build signal below
        args.empty? ? super : Build.new(obj).call(args)
      end
    end
    
    signal_class :list, Doc         # list available objects
    signal_class :help, Doc         # brings up this help
    signal_class :tutorial, Doc     # brings up a tutorial
    
    signal :enque                   # enques an object
    signal_class :build, Builder    # builds an object
    signal_class :parse, Parser     # 
    signal_class :use, Builder do   # enables middleware
      def call(argh)
        argh.unshift(nil) if argh.kind_of?(Array)
        super(argh)
      end
    end
    
    signal :run                     # run the app
    signal :stop                    # stop the app
    signal :terminate               # terminate the app
    signal :info                    # prints app status
    
    signal_class :exit do           # exit immediately
      def process(args) # :nodoc:
        exit(1)
      end
    end
    
    # Creates a new App with the given configuration.  Options can be used to
    # specify objects that are normally initialized for every new app:
    #
    #   :stack      the application stack; an App::Stack
    #   :queue      the application queue; an App::Queue
    #   :objects    application objects; a hash of (var, object) pairs
    #   :logger     the application logger
    #
    # A block may also be provided; it will be set as a default join.
    def initialize(config={}, options={}, &block)
      super() # monitor
      
      @state = State::READY
      @stack = options[:stack] || Stack.new(self)
      @queue = options[:queue] || Queue.new
      @objects = options[:objects] || {}
      @logger = options[:logger] || DEFAULT_LOGGER
      @joins = []
      on_complete(&block)
      
      self.env = config.delete(:env) || config.delete('env')
      initialize_config(config)
    end
    
    # Sets the application environment and validates that env provides an AGET
    # ([]) and invert method.  AGET is used to lookup constants during build;
    # it receives the 'class' parameter and should return a corresponding
    # class.  Invert should return an object that reverses the AGET lookup.
    # Tap::Env and a regular Hash both satisfy this api.
    #
    # Env can be set to nil and is set to nil by default, but building is
    # constrained without it.
    def env=(env)
      Validation.validate_api(env, [:[], :invert]) unless env.nil?
      @env = env
    end
    
    # True if the debug config or the global variable $DEBUG is true.
    def debug?
      debug || $DEBUG
    end
    
    # Logs the action and message at the input level (default INFO).  The
    # message may be generated by a block; in that case leave the message
    # unspecified as nil.
    #
    # Logging is suppressed if quiet is true.
    #
    # ==== Performance Considerations
    #
    # Using a block to generate a message is quicker if logging is off, but
    # slower when logging is on.  However, when messages use a lot of
    # interpolation the log time is dominated by the interpolation; at some
    # point the penalty for using a block is outweighed by the benefit of
    # being able to skip the interpolation.
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
    
    # Adds the specified middleware to the stack.  The argv will be used as
    # extra arguments to initialize the middleware.
    def use(middleware, *argv)
      synchronize do
        @stack = middleware.new(@stack, *argv)
      end
    end
    
    # Sets the object to the specified variable and returns obj.  Provide nil
    # as obj to un-set a variable (in which case the existing object is
    # returned).
    #
    # Nil is reserved as a variable name and cannot be used by set.
    def set(var, obj)
      raise "no var specified" if var.nil?
      
      if obj
        objects[var] = obj
      else
        objects.delete(var)
      end
    end
    
    # Returns the object set to var, or self if var is nil.
    def get(var)
      var.nil? ? self : objects[var]
    end
    
    # Same as get, but raises an error if no object is set to the variable.
    def obj(var)
      get(var) or raise "no object set to: #{var.inspect}"
    end
    
    # Returns the variable for the object.  If the object is not assigned to a
    # variable and auto_assign is true, then the object is set to an unused
    # variable and the new variable is returned.
    #
    # The new variable will be an integer and will be removed upon gc.
    def var(obj, auto_assign=true)
      objects.each_pair do |var, object|
        return var if obj == object
      end
      
      return nil unless auto_assign
      
      var = objects.length
      loop do 
        if objects.has_key?(var)
          var += 1
        else
          set(var, obj)
          return var
        end
      end
    end
    
    # Removes objects keyed by integers.  If all is specified, gc will clear
    # all objects.
    def gc(all=false)
      if all
        objects.clear
      else
        objects.delete_if {|var, obj| var.kind_of?(Integer) }
      end
      
      self
    end
    
    # Sends a signal to an application object.  The input should be a hash
    # defining these fields:
    #
    #   obj      # a variable identifying an object, or nil for self
    #   sig      # the signal name
    #   args     # arguments to the signal (typically a Hash)
    #
    # Call does the following:
    #
    #   object = app.get(obj)        # lookup an application object by obj
    #   signal = object.signal(sig)  # lookup a signal by sig
    #   signal.call(args)            # call the signal with args
    #
    # Call returns the result of the signal call.
    #
    def call(args)
      obj = args['obj']
      sig = args['sig']
      args = args['args'] || args
      
      unless object = get(obj)
        raise "unknown object: #{obj.inspect}"
      end
      
      unless object.respond_to?(:signal)
        raise "cannot signal: #{object.inspect}"
      end
      
      object.signal(sig).call(args)
    end
    
    def resolve(const_str)
      raise "no class specified" if const_str.nil? || const_str.empty?
      
      constant = env ? env[const_str] : Env::Constant.constantize(const_str)
      constant or raise "unresolvable constant: #{const_str.inspect}"
    end
    
    # Enques the application object specified by var with args.  Raises
    # an error if no such application object exists.
    def enque(var, *args)
      unless node = get(var)
        raise "unknown object: #{var.inspect}"
      end
      
      queue.enq(node, args)
      node
    end
    
    # Returns an array of middlware in use by self.
    def middleware
      middleware = []
      
      # collect middleware by walking up the stack
      synchronize do
        current = stack
        while current.respond_to?(:stack)
          middleware << current
          current = current.stack
        end
      end
      
      middleware
    end
    
    # Clears objects, the queue, and resets the stack so that no middleware
    # is used.  Reset raises an error unless state is READY.
    def reset
      synchronize do
        unless state == State::READY
          raise "cannot reset unless READY"
        end
        
        # walk up middleware to find the base of the stack
        while @stack.respond_to?(:stack)
          @stack = @stack.stack
        end
        
        objects.clear
        queue.clear
      end
    end
    
    # Execute is a wrapper for dispatch allowing inputs to be listed out
    # rather than provided as an array.
    def execute(node, *inputs)
      dispatch(node, inputs)
    end
    
    # Dispatch does the following in order:
    #
    # - call stack with the node and inputs
    # - call the node joins (node.joins)
    #
    # The joins for self will be called if the node joins are an empty array.
    # No joins will be called if the node joins are nil, or if the node does
    # not provide a joins method.
    #
    # Dispatch returns the stack result.
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
    # application stack.  A run continues until the queue is empty.  
    #
    # Run checks the state of self before dispatching a node.  If the state
    # changes from RUN, the following behaviors result:
    #   
    #   STOP        No more nodes will be dispatched; the current node
    #               will continute to completion.
    #   TERMINATE   No more nodes will be dispatched and the currently
    #               running node will be discontinued as described in
    #               terminate.
    #
    # Calls to run when the state is not READY do nothing and return
    # immediately.
    #
    # Returns self.
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
    # by setting state to STOP.  The node currently in the stack will continue
    # to completion.
    #
    # Does nothing unless state is RUN.
    def stop
      synchronize { @state = State::STOP if state == State::RUN }
      self
    end

    # Signals a running application to terminate execution by setting state to
    # TERMINATE.  In this state, calls to check_terminate will raise a
    # TerminateError.  Run considers TerminateErrors a normal exit and rescues
    # them quietly.
    #
    # Nodes can set breakpoints that call check_terminate to invoke
    # node-specific termination.  If a node never calls check_terminate, then
    # it will continue to completion.
    #
    # Does nothing if state is READY.
    def terminate
      synchronize { @state = State::TERMINATE unless state == State::READY }
      self
    end
    
    # Raises a TerminateError if state is TERMINATE.  Nodes should call
    # check_terminate to provide breakpoints in long-running processes.
    #  
    # A block may be provided to check_terminate to execute code before
    # raising the TerminateError.
    def check_terminate
      if state == State::TERMINATE
        yield() if block_given?
        raise TerminateError.new
      end
    end
    
    # Returns an information string for the App.  
    #
    #   App.new.info   # => 'state: 0 (READY) queue: 0'
    #
    def info
      "state: #{state} (#{State.state_str(state)}) queue: #{queue.size}"
    end
    
    # Dumps self to the target as YAML. (note dump is still experimental)
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
    
    # Converts the self to a schema that can be used to build a new app with
    # equivalent application objects, queue, and middleware.  Schema are a
    # collection of signal hashes such that this will rebuild the state of a
    # on b:
    #
    #   a, b = App.new, App.new
    #   a.to_schema.each {|spec| b.call(spec) }
    #
    # Application objects that do not satisfy the application object API are
    # quietly ignored; enable debugging to be warned of their existance.
    #
    def to_schema(bare=true)
      # setup variables
      specs = {}
      order = []
      
      # collect enque signals to setup queue
      signals = queue.to_a.collect do |(node, args)|
        {'sig' => 'enque', 'args' => [var(node)] + args}
      end
      
      # collect and trace application objects
      objects.keys.sort_by do |var|
        var.to_s
      end.each do |var|
        obj = objects[var]
        order.concat trace(obj, specs)
      end
      
      middleware.each do |obj|
        order.concat trace(obj, specs)
      end
      
      if bare
        order.delete(self)
        specs.delete(self)
      else
        order.unshift(self)
        trace(self, specs)
      end
      order.uniq!
      
      # assemble specs
      variables = {}
      objects.each_pair do |var, obj|
        (variables[obj] ||= []) << var
      end
      
      invert_env = env ? env.invert : nil
      specs.keys.each do |obj|
        spec = {}
        
        # assign variables
        if vars = variables[obj]
          if vars.length == 1
            spec['var'] = vars[0]
          else
            spec['var'] = vars
          end
        end

        # assign the class
        klass = obj.class
        klass = invert_env[klass] if invert_env
        spec['class'] = klass.to_s

        # merge obj_spec if possible
        obj_spec = specs[obj]
        if (obj_spec.keys & RESERVED_KEYS).empty?
          spec.merge!(obj_spec)
        else
          spec['spec'] = obj_spec
        end
        
        specs[obj] = spec
      end
      
      order.collect! {|obj| specs[obj] }.concat(signals)
    end
    
    def to_spec
      schema = to_schema(false)
      spec = schema.shift
      
      spec.delete('self')
      var = spec.delete('var')
      klass = spec.delete('class')
      spec = spec.delete('spec') || spec
      
      schema.unshift('var' => var, 'class' => klass, 'self' => true) if var
      spec['schema'] = schema
      
      spec
    end
    
    def inspect
      "#<#{self.class}:#{object_id} #{info}>"
    end

    private

    # Traces each object backwards and forwards for node, joins, etc. and adds
    # each to specs as needed.  The trace determines and returns the order in
    # which these specs must be initialized to make sense.  Circular traces
    # are detected.
    #
    # Note that order should not be provided for the first call; order must be
    # trace-specific.  For example (a -> b means 'a' references or requires
    # 'b' so read backwards for order):
    #
    #   # Circular trace [a,c,b,a]
    #   a -> b -> c -> a
    #
    #   # Not a problem [[b,a], [b,c]] => [b,a,c]
    #   a -> b
    #   c -> b
    #   
    def trace(obj, specs, order=[]) # :nodoc:
      if specs.has_key?(obj)
        return order
      end
      
      # check the object can be serialized
      unless obj.respond_to?(:to_spec)
        warn "cannot serialize: #{obj}"
        return order
      end
      specs[obj] = obj == self ? self_to_spec : obj.to_spec
      
      # trace references; refs must exist before obj and
      # obj must exist before brefs (back-references)
      if obj.respond_to?(:associations)
        refs, brefs = obj.associations
      
        refs.each {|ref| trace(ref, specs, order) } if refs
        order << obj
        brefs.each {|bref| trace(bref, specs, order) } if brefs
      else
        order << obj
      end
      
      order
    end
    
    def self_to_spec # :nodoc:
      config = self.config.to_hash {|hash, key, value| hash[key.to_s] = value }
      {'config' => config, 'self' => true}
    end
    
    # TerminateErrors are raised to kill executing nodes when terminate is 
    # called on an running App.  They are handled by the run rescue code.
    class TerminateError < RuntimeError
    end
  end
end