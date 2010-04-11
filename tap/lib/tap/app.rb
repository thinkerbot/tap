require 'logger'
require 'tap/app/api'
require 'tap/app/env'
require 'tap/app/node'
require 'tap/app/state'
require 'tap/app/stack'
require 'tap/app/queue'
require 'tap/join'
autoload(:YAML, 'yaml')

module Tap
  
  # :startdoc::app
  #
  # App coordinates the setup and execution of workflows.
  class App
    class << self
      def set_context(context={})
        current = Thread.current[CONTEXT]
        Thread.current[CONTEXT] = context
        current
      end
      
      def with_context(context)
        begin
          current = set_context(context)
          yield
        ensure
          set_context(current)
        end
      end
      
      def context
        Thread.current[CONTEXT] ||= {}
      end
      
      def instance=(app)
        context[INSTANCE] = app
      end
      
      def instance
        context[INSTANCE] ||= new
      end
      
      def build(spec={}, app=instance)
        config = spec['config'] || {}
        signals = spec['signals'] || []
        
        if spec['self']
          app.reconfigure(config)
        else
          app = new(config, :env => app.env)
        end
        
        signals.each do |args|
          app.call(args)
        end
        
        app.gc
        app
      end
    end
    
    include Configurable
    include MonitorMixin
    include Signals
    
    # A variable to store the application context in Thread.current
    CONTEXT  = 'tap.context'
    
    # A variable to store an instance in the application context.
    INSTANCE = 'tap.instance'
    
    # The reserved call keys
    CALL_KEYS = %w{obj sig args}
    
    # The reserved init keys
    INIT_KEYS = %w{var class spec}
    
    # Reserved call and init keys as a single array
    RESERVED_KEYS = CALL_KEYS + INIT_KEYS
    
    # Splits a signal into an object string and a signal string.  If OBJECT
    # doesn't match, then the string can be considered a signal, and the
    # object is nil. After a match:
    #
    #   $1:: The object string
    #        (ex: 'obj/sig' => 'obj')
    #   $2:: The signal string
    #        (ex: 'obj/sig' => 'sig')
    #
    OBJECT = /\A(.*)\/(.*)\z/
    
    # The default App logger (writes to $stderr at level INFO)
    DEFAULT_LOGGER = Logger.new($stderr)
    DEFAULT_LOGGER_FORMAT = "%s %8s %10s %s\n"
    DEFAULT_LOGGER.formatter = lambda do |severity, time, head, tail|
      code = (severity == 'INFO' ? ' ' : severity[0,1])
      DEFAULT_LOGGER_FORMAT % [code, time.strftime('%H:%M:%S'), head, tail]
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
    
    # The application environment
    attr_accessor :env
    
    # The application joins
    attr_reader :joins
    
    config :debug, false, :short => :d, &c.flag     # Flag debugging
    config :force, false, :short => :f, &c.flag     # Force execution at checkpoints
    config :quiet, false, :short => :q, &c.flag     # Suppress logging
    config :verbose, false, :short => :v, &c.flag   # Enables extra logging (overrides quiet)
    
    signal :exe do |sig, argv|                      # executes an object
      var, *input = argv
      [sig.obj.obj(var), input]
    end
    
    signal :enq do |sig, argv|                      # enques an object
      var, *input = argv
      [sig.obj.obj(var), input]
    end
    
    signal :pq do |sig, argv|                       # priority-enques an object
      var, *input = argv
      [sig.obj.obj(var), input]
    end
    
    signal_hash :set,                               # set or unset objects
      :signature => ['var', 'class'],
      :remainder => 'spec',
      :bind => :build
    
    signal :get,                                    # get objects
      :signature => ['var']
    
    signal_hash :bld,                               # build an object
      :signature => ['class'],
      :remainder => 'spec',
      :bind => :build
    
    define_signal :use do |input|                   # enables middleware
      spec = convert_to_hash(input, ['class'], 'spec')
      obj.stack = obj.build(spec, &block)
    end
    
    define_signal :configure, Configure             # configures the app
    
    signal :reset                                   # reset the app
    signal :run                                     # run the app
    signal :stop                                    # stop the app
    signal :terminate                               # terminate the app
    signal :info                                    # prints app status
    
    define_signal :list do |input|                  # list available objects
      lines = obj.objects.collect {|(key, obj)|  "#{key}: #{obj.class}" }
      lines.empty? ? "No objects yet..." : lines.sort.join("\n")
    end
    
    define_signal :serialize do |input|             # serialize the app as signals
      if input.kind_of?(Array)
        psr = ConfigParser.new
        psr.on('--[no-]bare') {|value| psr['bare'] = value }
        path, *ignored = psr.parse!(input)
        psr['path'] = path
        input = psr.config
      end
      
      bare = input.has_key?('bare') ? input['bare'] : true
      signals = obj.serialize(bare)
      
      if path = input['path']
        File.open(path, "w") {|io| YAML.dump(signals, io) }
      else
        YAML.dump(signals, $stdout)
      end
      
      obj
    end
    
    define_signal :import do |input|                # import serialized signals
      paths = convert_to_array(input, ['paths'])
      paths.each do |path|
        YAML.load_file(path).each do |signal|
          obj.call(signal)
        end
      end
      
      obj
    end
    
    define_signal :load, Load                       # load a tapfile
    define_signal :help, Help                       # signals help
    
    cache_signals
    
    # Creates a new App with the given configuration.  Options can be used to
    # specify objects that are normally initialized for every new app:
    #
    #   :stack      the application stack; an App::Stack
    #   :queue      the application queue; an App::Queue
    #   :objects    application objects; a hash of (var, object) pairs
    #   :logger     the application logger
    #   :env        the application environment
    #
    # A block may also be provided; it will be set as a default join.
    def initialize(config={}, options={}, &block)
      super() # monitor
      
      @state = State::READY
      @stack = options[:stack] || Stack.new(self)
      @queue = options[:queue] || Queue.new
      @objects = options[:objects] || {}
      @logger = options[:logger] || DEFAULT_LOGGER
      @env = options[:env] || Env.new
      @joins = []
      
      on_complete(&block)
      initialize_config(config)
    end
    
    # Sets the application stack.
    def stack=(stack)
      synchronize do
        @stack = stack
      end
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
    def log(action='', msg=nil, level=Logger::INFO)
      if !quiet || verbose
        msg = yield if msg.nil? && block_given?
        logger.add(level, msg.to_s, action.to_s)
      end
    end
    
    # Returns a new node that executes block on call.
    def node(var=nil, &block) # :yields: *args
      node = Node.new(block, self)
      set(var, node) if var
      node
    end
    
    # Generates a join between the inputs and outputs.  Join resolves the
    # class using env and initializes a new instance with the configs and
    # self. 
    def join(inputs, outputs, config={}, clas=Join, &block)
      inputs  = [inputs]  unless inputs.kind_of?(Array)
      outputs = [outputs] unless outputs.kind_of?(Array)
      init(clas, config, self).join(inputs, outputs, &block)
    end
    
    # Enques the node with the input.  Returns the node.
    def enq(node, input)
      queue.enq(node, input)
      node
    end
    
    # Priority-enques (unshifts) the node with the input.  Returns the node.
    def pq(node, input)
      queue.unshift(node, input)
      node
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
    def call(args, &block)
      obj = args['obj']
      sig = args['sig']
      args = args['args'] || args
      
      # nil obj routes back to app, so optimize by evaluating signal directly
      (obj.nil? ? signal(sig, &block) : route(obj, sig, &block)).call(args)
    end
    
    def signal(sig, &block)
      sig = sig.to_s
      sig =~ OBJECT ? route($1, $2, &block) : super(sig, &block)
    end
    
    def route(obj, sig, &block)
      unless object = get(obj)
        raise "unknown object: #{obj.inspect}"
      end
      
      unless object.respond_to?(:signal)
        raise "cannot signal: #{object.inspect}"
      end
      
      object.signal(sig, &block)
    end
    
    # Resolves the class in env and initializes a new instance with the args
    # and block.  Note that the app is not appended to args by default.
    def init(clas, *args, &block)
      env.constant(clas).new(*args, &block)
    end
    
    def build(spec, &block)
      var = spec['var']
      clas = spec['class']
      spec = spec['spec'] || spec
      
      obj = nil
      unless clas.nil?
        method_name = spec.kind_of?(Array) ? :parse : :build
        obj = env.constant(clas).send(method_name, spec, self, &block)
      end
      
      unless var.nil?
        if var.respond_to?(:each)
          var.each {|v| set(v, obj) }
        else
          set(var, obj)
        end
      end
      
      obj
    end
    
    # Adds the specified middleware to the stack.  The argv will be used as
    # extra arguments to initialize the middleware.
    def use(clas, *argv)
      synchronize do
        @stack = init(clas, @stack, *argv)
      end
    end
    
    # Returns an array of middlware in use by self.
    def middleware
      middleware = []
      
      # collect middleware by walking up the stack
      synchronize do
        current = stack
        visited = [current]
        
        while current.respond_to?(:stack)
          middleware << current
          current = current.stack
          
          circular_stack = visited.include?(current)
          visited << current
          
          if circular_stack
            visited.collect! {|m| m.class.to_s }.join(', ')
            raise "circular stack detected:\n[#{visited}]"
          end
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
      self
    end
    
    # Executes nodes by doing the following.
    #
    # - call stack with the node and input
    # - call the node joins (node.joins)
    #
    # Returns the stack result.
    def exe(node, input)
      result = stack.call(node, input)
      
      if node.respond_to?(:joins)
        if joins = node.joins
          joins.each do |join|
            join.call(result)
          end
        end
      end
      
      result
    end
    
    # Sequentially executes each enqued job (a [node, input] pair).  A run
    # continues until the queue is empty.
    #
    # Run checks the state of self before executing a node.  If the state
    # changes from RUN, the following behaviors result:
    #       
    #   STOP        No more nodes will be executed; the current node
    #               will continute to completion.
    #   TERMINATE   No more nodes will be executed and the currently
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
          break unless job = queue.deq
          exe(*job)
        end
      rescue(TerminateError)
        # gracefully fail for termination errors
        queue.unshift(*job)
      ensure
        synchronize { @state = State::READY }
      end
      
      self
    end
    
    # Signals a running app to stop executing nodes to the application stack
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
    
    # Sets the block as a join for self.
    def on_complete(&block) # :yields: result
      joins << block if block
      self
    end
    
    # Sets self as instance in the current context, for the duration of the
    # block (see App.with_context).
    def scope
      App.with_context(APP => self) { yield }
    end
    
    def eval(str, filename=nil, lineno=0)
      Kernel.eval(str, binding, filename, lineno)
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
    def serialize(bare=true)
      # setup variables
      specs = {}
      order = []
      
      # collect enque signals to setup queue
      signals = queue.to_a.collect do |(node, input)|
        {'sig' => 'enq', 'args' => [var(node), input]}
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
      
      specs.keys.each do |obj|
        spec = {'sig' => 'set'}
        
        # assign variables
        if vars = variables[obj]
          if vars.length == 1
            spec['var'] = vars[0]
          else
            spec['var'] = vars
          end
        end

        # assign the class
        spec['class'] = obj.class.to_s

        # merge obj_spec if possible
        obj_spec = specs[obj]
        if (obj_spec.keys & RESERVED_KEYS).empty?
          spec.merge!(obj_spec)
        else
          spec['spec'] = obj_spec
        end
        
        specs[obj] = spec
      end
      
      middleware.each do |obj|
        spec = specs[obj]
        spec['sig'] = 'use'
      end
      
      order.collect! {|obj| specs[obj] }.concat(signals)
    end
    
    def to_spec
      signals = serialize(false)
      spec = signals.shift
      
      spec.delete('self')
      spec.delete('sig')
      
      var = spec.delete('var')
      klass = spec.delete('class')
      spec = spec.delete('spec') || spec
      
      signals.unshift(
        'sig' => 'set',
        'var' => var, 
        'class' => klass, 
        'self' => true
      ) if var
      spec['signals'] = signals
      
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
        
        unless array_or_nil?(refs) && array_or_nil?(brefs)
          raise "invalid associations on object (refs, brefs must be an array or nil): #{obj.inspect}"
        end
      
        refs.each {|ref| trace(ref, specs, order) } if refs
        order << obj
        brefs.each {|bref| trace(bref, specs, order) } if brefs
      else
        order << obj
      end
      
      order
    end
    
    def array_or_nil?(obj) # :nodoc:
      obj.nil? || obj.kind_of?(Array)
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