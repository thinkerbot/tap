require 'logger'
require 'tap/app/api'
require 'tap/app/env'
require 'tap/app/node'
require 'tap/app/state'
require 'tap/app/stack'
require 'tap/app/queue'
require 'tap/parser'
autoload(:YAML, 'yaml')

module Tap
  
  # :startdoc::app
  #
  # App coordinates the setup and execution of workflows.
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
      
      def build(spec={}, app=Tap::App.instance)
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
    include Node
    
    # The reserved call keys
    CALL_KEYS = %w{obj sig args}
    
    # The reserved init keys
    INIT_KEYS = %w{var class spec}
    
    # Reserved call and init keys as a single array
    RESERVED_KEYS = CALL_KEYS + INIT_KEYS
    
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
    
    # The application environment
    attr_accessor :env
    
    config :debug, false, :short => :d, &c.flag      # Flag debugging
    config :force, false, :short => :f, &c.flag      # Force execution at checkpoints
    config :quiet, false, :short => :q, &c.flag      # Suppress logging
    config :verbose, false, :short => :v, &c.flag    # Enables extra logging (overrides quiet)
    config :bang, true, &c.switch                    # Use parse! in build/parse signals
    
    signal :enq do |sig, argv|                       # enques an object
      argv[0] = sig.obj.obj(argv[0])
      argv
    end
    
    signal :pq do |sig, argv|                       # priority-enques an object
      argv[0] = sig.obj.obj(argv[0])
      argv
    end
    
    signal_hash :set,                                # set or unset objects
      :signature => ['var', 'class'],
      :remainder => 'spec',
      :bind => :build
      
    signal :get,                                     # get objects
      :signature => ['var']
    
    signal :resolve,                                 # resolve a constant in env
      :signature => ['constant']
    
    signal_hash :build,                              # build an object
      :signature => ['class'],
      :remainder => 'spec'
    
    signal_class :parse do                           # parse a workflow
      def call(args) # :nodoc:
        argv = convert_to_array(args, ['args'])
        obj.send(obj.bang ? :parse! : :parse, argv, &block)
      end
    end
    
    signal_class :use do                             # enables middleware
      def call(args) # :nodoc:
        spec = convert_to_hash(args, ['class'], 'spec')
        obj.stack = obj.build(spec, &block)
      end
    end
    
    signal_class :configure do                       # configures the app
      def call(config) # :nodoc:
        if config.kind_of?(Array)
          psr = ConfigParser.new(:add_defaults => false)
          psr.add(obj.class.configurations)
          args = psr.parse!(config)
          obj.send(:warn_ignored_args, args)
          
          config = psr.config
        end
        
        obj.reconfigure(config)
        obj.config
      end
    end
    
    signal :reset                                    # reset the app
    signal :run                                      # run the app
    signal :stop                                     # stop the app
    signal :terminate                                # terminate the app
    signal :info                                     # prints app status
    
    signal_class :list do                            # list available objects
      def call(args) # :nodoc:
        lines = obj.objects.collect {|(key, obj)|  "#{key}: #{obj.class}" }
        lines.empty? ? "No objects yet..." : lines.sort.join("\n")
      end
    end
    
    signal_class :exec do
      def call(args) # :nodoc:
        paths = convert_to_array(args, ['paths'])
        paths.each do |path|
          File.open(path) do |io|
            Parser.each_signal(io) do |sig|
              obj.call(sig)
            end
          end
        end
        
        obj
      end
    end
    
    signal_class :serialize do                       # serialize the app as signals
      def call(args) # :nodoc:
        if args.kind_of?(Array)
          psr = ConfigParser.new
          psr.on('--[no-]bare') {|value| psr['bare'] = value }
          path, *ignored = psr.parse!(args)
          psr['path'] = path
          args = psr.config
        end
        
        bare = args.has_key?('bare') ? args['bare'] : true
        signals = obj.serialize(bare)
        
        if path = args['path']
          File.open(path, "w") {|io| YAML.dump(signals, io) }
        else
          YAML.dump(signals, $stdout)
        end
        
        obj
      end
    end
    
    signal_class :import do                          # import serialized signals
      def call(args) # :nodoc:
        paths = convert_to_array(args, ['paths'])
        paths.each do |path|
          YAML.load_file(path).each do |signal|
            obj.call(signal)
          end
        end
        
        obj
      end
    end
    
    signal :load, :class => Load, :bind => nil
    
    signal :help, :class => Help, :bind => nil       # signals help
    
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
    
    # Priority-enques (unshifts) the node with the inputs.  Returns the node.
    def pq(node, *inputs)
      queue.unshift(node, inputs)
      node
    end
    
    # Generates a node from the block and enques. Returns the new node.
    def bq(*inputs, &block) # :yields: *inputs
      node = self.node(&block)
      queue.enq(node, inputs)
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
    #
    def call(args, &block)
      obj = args['obj']
      sig = args['sig']
      args = args['args'] || args
      
      route(obj, sig, &block).call(args)
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

    def resolve(key)
      env.get(key) or raise "unresolvable constant: #{key.inspect}"
    end
    
    def build(spec)
      var = spec['var']
      clas = spec['class']
      spec = spec['spec'] || spec
      obj = nil
      
      if clas.nil?
        unless spec.empty?
          raise "no class specified"
        end
      else
        clas = resolve(clas)
        
        case spec
        when Array
          parse = bang ? :parse! : :parse
          obj, args = clas.send(parse, spec, self)
      
          if block_given?
            yield(obj, args)
          else
            warn_ignored_args(args)
          end
        
        when Hash
          obj = clas.build(spec, self)
        else
          raise "invalid spec: #{spec.inspect}"
        end
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
    
    def parse(argv, &block) # :yields: spec
      parse!(argv.dup, &block)
    end
    
    def parse!(argv, &block) # :yields: spec
      parser = Parser.new
      argv = parser.parse!(argv)
      
      # The queue API does not provide a delete method, so picking out the
      # deque jobs requires the whole queue be cleared, then re-enqued.
      # Safety (and speed) is improved with synchronization.
      queue.synchronize do
        deque = []
        
        node_block = lambda do |obj, args|
          queue.enq(obj, args)
        end
        
        join_block = lambda do |obj, args|
          if obj.respond_to?(:outputs)
            deque.concat obj.outputs
          end
          warn_ignored_args(args)
        end
        
        parser.specs.each do |spec|
          if block_given?
            next unless yield(spec)
          end
          
          type, obj, sig, *args = spec
          
          sig_block = case sig
          when 'set'
            case type
            when :node
              node_block
            when :join
              join_block
            else 
              nil
            end
          when 'parse'
            block
          else
            nil
          end
          
          call('obj' => obj, 'sig' => sig, 'args' => args, &sig_block)  
        end
        
        deque.uniq!
        queue.clear.each do |(obj, args)|
          if deque.delete(obj)
            warn_ignored_args(args)
          else
            queue.enq(obj, args)
          end
        end
      end

      argv
    end
    
    # Adds the specified middleware to the stack.  The argv will be used as
    # extra arguments to initialize the middleware.
    def use(middleware, *argv)
      synchronize do
        @stack = middleware.new(@stack, *argv)
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
            visited.collect! {|middleware| middleware.class.to_s }.join(', ')
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
    def serialize(bare=true)
      # setup variables
      specs = {}
      order = []
      
      # collect enque signals to setup queue
      signals = queue.to_a.collect do |(node, args)|
        {'sig' => 'enq', 'args' => [var(node)] + args}
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
    
    # warns of ignored args
    def warn_ignored_args(args) # :nodoc:
      if args && debug? && !args.empty?
        warn "ignoring args: #{args.inspect}"
      end
    end
    
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