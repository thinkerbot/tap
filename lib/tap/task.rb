require 'tap/support/batchable'
require 'tap/support/executable'
require 'tap/support/command_line'

module Tap

  # Tasks are the basic organizational unit of Tap.  Tasks provide
  # a standard backbone for creating the working parts of an application
  # by facilitating configuration, batched execution of methods, and 
  # documentation.
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
  #   t.string = 1           # !> ValidationError
  #   t.integer = 1.1        # !> ValidationError
  #
  #   t.integer = "1"
  #   t.integer == 1         # => true 
  #
  # Tasks have a name that gets used in auditing, and as a relative 
  # filepath to find associated files (for instance config files). 
  # By default the task name is based on the task class, such that 
  # Tap::Task has the default name 'tap/task'.  Configurations
  # and custom names can be provided when a task is initialized.
  #
  #   t = ConfiguredTask.new({:one => 'ONE', :three => 'three'}, "example")
  #   t.name                 # => "example"
  #   t.config               # => {:one => 'ONE', :two => 'two', :three => 'three'}
  #
  # === Batches
  #  
  # Tasks can be assembled into batches that enque and execute collectively.
  # Batched tasks are often alternatively-configured derivatives of one 
  # parent task, although they can be manually assembled using Task.batch.
  #
  #   app = Tap::App.instance
  #   t1 = Tap::Task.new(:key => 'one') do |task, input| 
  #     input + task.config[:key]
  #   end
  #   t1.batch               # => [t1]
  #
  #   t2 = t1.initialize_batch_obj(:key => 'two')
  #   t1.batch               # => [t1, t2]
  #   t2.batch               # => [t1, t2]
  #   
  #   t1.enq 't1_by_'
  #   t2.enq 't2_by_'
  #   app.run
  #
  #   app.results(t1)        # => ["t1_by_one", "t2_by_one"]
  #   app.results(t2)        # => ["t1_by_two", "t2_by_two"]
  #
  # Here the results reflects that t1 and t2 were run in succession with the 
  # input to t1, and then the input to t2.
  #
  # === Subclassing
  # Tasks can be subclassed normally, with one reminder related to batching.
  #
  # Batched tasks are generated by duplicating an existing instance, hence
  # all instance variables will point to the same object in the batched
  # and original task.  At times (as with configurations), this is 
  # undesirable; the batched task should have it's own copy of an 
  # instance variable.
  #
  # In these cases, the <tt>initialize_copy</tt> should be overridden
  # and should re-initialize the appropriate variables.  Be sure to call
  # super to invoke the default <tt>initialize_copy</tt>:
  #
  #   class SubclassTask < Tap::Task
  #     attr_accessor :array
  #     def initialize(*args)
  #       @array = []
  #       super
  #     end
  #  
  #     def initialize_copy(orig)
  #       @array = orig.array.dup
  #       super
  #     end
  #   end
  #
  #   t1 = SubclassTask.new
  #   t2 = t1.initialize_batch_obj
  #   t1.array == t2.array                         # => true
  #   t1.array.object_id == t2.array.object_id     # => false
  #
  class Task
    include Support::Batchable
    include Support::Configurable
    include Support::Executable
    
    class << self
      # Returns the default name for the class: to_s.underscore
      attr_accessor :default_name

      # Returns class dependencies
      attr_reader :dependencies
      
      def inherited(child)
        unless child.instance_variable_defined?(:@source_file)
          caller.first =~ Support::Lazydoc::CALLER_REGEXP
          child.instance_variable_set(:@source_file, File.expand_path($1)) 
        end

        child.instance_variable_set(:@default_name, child.to_s.underscore)
        child.instance_variable_set(:@dependencies, dependencies.dup)
        super
      end
      
      def instance
        @instance ||= new
      end
      
      # Generates or updates the specified subclass of self.
      def subclass(const_name, configs={}, dependencies=[], options={}, &block)
        #
        # Lookup or create the subclass constant. 
        #
        
        current, constants = const_name.to_s.constants_split
        subclass = if constants.empty?
          # The constant exists; validate the constant is a subclass of self.
          unless current.kind_of?(Class) && current.ancestors.include?(self)
            raise ArgumentError, "#{current} is already defined and is not a subclass of #{self}!"
          end
          current
        else
          # Generate the nesting module
          subclass_const = constants.pop
          constants.each {|const| current = current.const_set(const, Module.new)}

          # Create and set the subclass constant
          current.const_set(subclass_const, Class.new(self))
        end
        
        #
        # Define the subclass
        #
        
        subclass.define_configurations(configs)
        subclass.define_dependencies(dependencies)
        subclass.define_process(block) if block_given?
  
        #
        # Register documentation
        #
        
        const_name = current == Object ? subclass_const : "#{current}::#{subclass_const}"
        caller.each_with_index do |line, index|
          case line
          when /\/tap\/support\/declarations.rb/ then next
          when Support::Lazydoc::CALLER_REGEXP
            subclass.source_file = File.expand_path($1)
            lzd = subclass.lazydoc(false)
            lzd[const_name, false]['manifest'] = lzd.register($3.to_i - 1)            
            break
          end
        end

        arity = options[:arity] || (block_given? ? block.arity : -1)
        comment = Support::Comment.new
        comment.subject = case
        when arity > 0
          Array.new(arity, "INPUT").join(' ')
        when arity < 0
          array = Array.new(-1 * arity - 1, "INPUT")
          array << "INPUTS..."
          array.join(' ')
        else ""
        end
        subclass.lazydoc(false)[const_name, false]['args'] ||= comment

        subclass.default_name = const_name.underscore
        subclass
      end
      
      def instantiate(argv, app=Tap::App.instance) # => instance, argv
        opts = OptionParser.new

        # Add configurations
        config = {}
        unless configurations.empty?
          opts.separator ""
          opts.separator "configurations:"
        end

        configurations.each do |receiver, key, configuration|
          opts.on(*Support::CommandLine.configv(configuration)) do |value|
            config[key] = value
          end
        end

        # Add options on_tail, giving priority to configurations
        opts.separator ""
        opts.separator "options:"

        opts.on_tail("-h", "--help", "Print this help") do
          opts.banner = "#{help}usage: tap run -- #{to_s.underscore} #{args.subject}"
          puts opts
          exit
        end

        # Add option for name
        name = default_name
        opts.on_tail('--name NAME', /^[^-].*/, 'Specify a name') do |value|
          name = value
        end

        # Add option to add args
        use_args = []
        opts.on_tail('--use FILE', /^[^-].*/, 'Loads inputs from file') do |value|
          obj = YAML.load_file(value)
          case obj
          when Hash 
            obj.values.each do |array|
              # error if value isn't an array
              use_args.concat(array)
            end
          when Array 
            use_args.concat(obj)
          else
            use_args << obj
          end
        end

        opts.parse!(argv)
        obj = new({}, name, app)

        path_configs = load_config(app.config_filepath(name))
        if path_configs.kind_of?(Array)
          path_configs.each_with_index do |path_config, i|
            obj.initialize_batch_obj(path_config, "#{name}_#{i}") unless i == 0
          end
          path_configs = path_configs[0]
        end

        argv = (argv + use_args).collect {|str| str =~ /\A---\s*\n/ ? YAML.load(str) : str }

        [obj.reconfigure(path_configs).reconfigure(config), argv]
      end

      def lazydoc(resolve=true)
        lazydoc = super(false)
        lazydoc.register_method_pattern('args', :process) unless lazydoc.resolved?
        super
      end

      DEFAULT_HELP_TEMPLATE = %Q{<% manifest = task_class.manifest %>
<%= task_class %><%= manifest.subject.to_s.strip.empty? ? '' : ' -- ' %><%= manifest.subject %>

<% unless manifest.empty? %>
<%= '-' * 80 %>

<% manifest.wrap(77, 2, nil).each do |line| %>
  <%= line %>
<% end %>
<%= '-' * 80 %>
<% end %>

}
      def help
        Tap::Support::Templater.new(DEFAULT_HELP_TEMPLATE, :task_class => self).build
      end
      
      def depends_on(dependency_class, *args)
        unless dependency_class.respond_to?(:instance)
          raise ArgumentError, "dependency_class does not respond to instance: #{dependency_class}"
        end
        (dependencies << [dependency_class, args]).uniq!
        self
      end
      
      protected
      
      def dependency(name, dependency_class, *args)
        depends_on(dependency_class, *args)

        define_method(name) do
          index = Support::Executable.index(dependency_class.instance, args)
          Support::Executable.results[index]._current
        end
        
        public(name)
      end
      
      def define(name, klass=Tap::Task, &block)
        instance_var = "@#{name}".to_sym
        
        define_method(name) do |*args|
          raise ArgumentError, "wrong number of arguments (#{args.length} for 1)" if args.length > 1
          
          instance_name = args[0] || name
          instance_variable_set(instance_var, {}) unless instance_variable_defined?(instance_var)
          instance_variable_get(instance_var)[instance_name] ||= config_task(instance_name, klass, &block)
        end
        
        define_method("#{name}=") do |input|
          input = {name => input} unless input.kind_of?(Hash)
          instance_variable_set(instance_var, input)
        end
        
        public(name, "#{name}=")
      end
      
      def define_configurations(configs)
        case configs
        when Hash
          # hash configs are simply added as default configurations
          attr_accessor(*configs.keys)
          configs.each_pair do |key, value|
            configurations.add(key, value)
          end
          public(*configs.keys)
        when Array
          # array configs define configuration methods
          configs.each do |method, key, value, opts, config_block| 
            send(method, key, value, opts, &config_block)
          end
        else 
          raise ArgumentError, "cannot define configurations from: #{configs}"
        end
      end
      
      def define_dependencies(dependencies)
        dependencies.each do |name, dependency_class, *args|
          dependency(name, dependency_class, *args)
        end if dependencies
      end
      
      def define_process(block)
        send(:define_method, :process, &block)
      end
    end
    
    instance_variable_set(:@source_file, __FILE__)
    instance_variable_set(:@default_name, 'tap/task')
    instance_variable_set(:@dependencies, [])
    lazy_attr :manifest
    lazy_attr :args
    
    # The application used to load config_file templates 
    # (and hence, to initialize batched objects).
    attr_reader :app
    
    # The name of self.
    #--
    # Currently names may be any object.  Audit makes use of name
    # via to_s, as does app when figuring configuration filepaths. 
    attr_accessor :name
    
    # The task block provided during initialization.  
    attr_reader :task_block

    # Initializes a new instance and associated batch objects.  Batch
    # objects will be initialized for each configuration template 
    # specified by app.each_config_template(config_file) where 
    # config_file = app.config_filepath(name).  
    def initialize(config={}, name=nil, app=App.instance, &task_block)
      super()
      
      @app = app
      @name = name || self.class.default_name
      @task_block = (task_block == nil ? default_task_block : task_block)
      
      @_method_name = :execute
      @on_complete_block = nil
      @dependencies = []
      
      case config
      when Support::InstanceConfiguration 
        @config = config
        config.bind(self)
      else 
        initialize_config(config)
      end
      
      self.class.dependencies.each do |task_class, args|
        depends_on(task_class.instance, *args)
      end
    end
    
    # Creates a new batched object and adds the object to batch. The batched object 
    # will be a duplicate of the current object but with a new name and/or 
    # configurations.
    def initialize_batch_obj(overrides={}, name=nil)
      obj = super().reconfigure(overrides)
      obj.name = name if name
      obj 
    end
    
    # Enqueues self and self.batch to app with the inputs.  
    # The number of inputs provided should match the number 
    # of inputs specified by the arity of the _method_name method.
    def enq(*inputs)
      app.queue.enq(self, inputs)
    end

    batch_function :enq
    batch_function(:on_complete) {}
    
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

    # Raises a TerminateError if app.state == State::TERMINATE.
    # check_terminate may be called at any time to provide a 
    # breakpoint in long-running processes.
    def check_terminate
      if app.state == App::State::TERMINATE
        raise App::TerminateError.new
      end
    end
    
    # Returns self.name
    def to_s
      name.to_s
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
    
    private
    
    def config_task(name, klass=Tap::Task, &block)
      configs = config[name] || {}
      raise ArgumentError, "config '#{name}' is not a hash" unless configs.kind_of?(Hash)
      klass.new(configs, name, &block)
    end
  end
end