require 'tap/support/executable'
require 'tap/support/lazydoc/method'
autoload(:OptionParser, 'optparse')

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
      
      #--
      # use with caution... should reset dependencies?
      attr_writer :instance
      
      # Returns an instance of self; the instance is a kind of 'global'
      # instance used in class-level dependencies.  See depends_on.
      def instance
        @instance ||= new
      end

      # Parses the argv into an instance of self and an array of arguments (implicitly
      # to be enqued to the instance and run by app).  Yields a help string to the
      # block when the argv indicates 'help'.
      #
      def parse(argv=ARGV, app=Tap::App.instance, &block) # :yields: help_str
        parse!(argv.dup, &block)
      end
      
      # Same as parse, but removes switches destructively. 
      def parse!(argv=ARGV, app=Tap::App.instance) # :yields: help_str
        opts = OptionParser.new

        # Add configurations
        argv_config = {}
        unless configurations.empty?
          opts.separator ""
          opts.separator "configurations:"
        end

        configurations.each do |receiver, key, config|
          opts.on(*config.to_optparse_argv) do |value|
            argv_config[key] = value
          end
        end

        # Add options on_tail, giving priority to configurations
        opts.separator ""
        opts.separator "options:"

        opts.on_tail("-h", "--help", "Print this help") do
          opts.banner = "#{help}usage: tap run -- #{to_s.underscore} #{args.subject}"
          if block_given? 
            yield(opts.to_s)
          else
            puts opts
            exit
          end
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
        
        # parse the argv
        opts.parse!(argv)
        
        # build and reconfigure the instance and any associated
        # batch objects as specified in the file configurations
        obj = new({}, name, app)
        path_configs = load_config(app.config_filepath(name))
        if path_configs.kind_of?(Array)
          path_configs.each_with_index do |path_config, i|
            next if i == 0
            batch_obj = obj.initialize_batch_obj(path_config, "#{name}_#{i}")
            batch_obj.reconfigure(argv_config)
          end
          path_configs = path_configs[0]
        end
        obj.reconfigure(path_configs).reconfigure(argv_config)
        
        # recollect arguments
        argv = (argv + use_args).collect {|str| str =~ /\A---\s*\n/ ? YAML.load(str) : str }

        [obj, argv]
      end
      
      def execute(argv=ARGV)
        instance, args = parse(ARGV) do |help|
          puts help
          exit
        end

        instance.execute(*args)
      end

      def lazydoc(resolve=true)
        lazydoc = super(false)
        lazydoc[self.to_s]['args'] ||= lazydoc.register_method(:process, Support::Lazydoc::Method)
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
      
      # Sets a class-level dependency.  When task class B depends_on another task 
      # class A, instances of B are initialized to depend on A.instance, with the
      # specified arguments.  Returns self.
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
        
        undef_method(name) if method_defined?(name)
        define_method(name) do
          index = app.dependencies.index(dependency_class.instance, args)
          app.dependencies.resolve([index])
          app.dependencies.results[index]._current
        end
        
        public(name)
      end
      
      def define(name, klass=Tap::Task, config=klass.configurations.to_hash, &block)
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
        
        configurations.add(name, config, :reader => nil, :writer => nil)
      end
    end
    
    instance_variable_set(:@source_file, __FILE__)
    instance_variable_set(:@default_name, 'tap/task')
    instance_variable_set(:@dependencies, [])
    lazy_attr :manifest
    lazy_attr :args
    
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

      @name = name || self.class.default_name
      @task_block = (task_block == nil ? default_task_block : task_block)
      
      @app = app
      @_method_name = :execute_with_callbacks
      @on_complete_block = nil
      @dependencies = []
      @batch = [self]
      
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
      
      workflow
    end
    
    # Creates a new batched object and adds the object to batch. The batched object 
    # will be a duplicate of the current object but with a new name and/or 
    # configurations.
    def initialize_batch_obj(overrides={}, name=nil)
      obj = super().reconfigure(overrides)
      obj.name = name if name
      obj 
    end

    # Executes self with the given inputs.  Execute provides hooks for subclasses
    # to insert standard execution code: before_execute, on_execute_error,
    # and after_execute.  Override any/all of these methods as needed.
    #
    # Execute passes the inputs to process and returns the result.
    def execute(*inputs)  
      _execute(*inputs)._current
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
    
    # Returns self.name
    def to_s
      name.to_s
    end
    
    # Provides an abbreviated version of the default inspect, with only
    # the task class, object_id, name, and configurations listed.
    def inspect
      "#<#{self.class.to_s}:#{object_id} #{name} #{config.to_hash.inspect} >"
    end
    
    protected
    
    # Hook to set a default task block.  By default, nil.
    def default_task_block
      nil
    end
    
    # Hook to define a workflow for defined tasks.
    def workflow
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
    
    def execute_with_callbacks(*inputs)  
      before_execute
      begin
        result = process(*inputs)
      rescue
        on_execute_error($!)
      end
      after_execute
       
      result
    end
    
    def config_task(name, klass=Tap::Task, &block)
      configs = config[name] || {}
      raise ArgumentError, "config '#{name}' is not a hash" unless configs.kind_of?(Hash)
      klass.new(configs, name, &block)
    end
    
  end
end