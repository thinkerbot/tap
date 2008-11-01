require 'tap/support/executable'
require 'tap/support/lazydoc/method'
require 'tap/support/lazydoc/definition'
require 'tap/support/intern'
autoload(:OptionParser, 'optparse')

module Tap

  # === Task Definition
  #
  # Tasks specify executable code by overridding the process method in
  # subclasses. The number of inputs to process corresponds to the inputs
  # given to execute or enq.
  #
  #   class NoInput < Tap::Task
  #     def process(); []; end
  #   end
  #
  #   class OneInput < Tap::Task
  #     def process(input); [input]; end
  #   end
  #
  #   class MixedInputs < Tap::Task
  #     def process(a, b, *args); [a,b,args]; end
  #   end
  #
  #   NoInput.new.execute                          # => []
  #   OneInput.new.execute(:a)                     # => [:a]
  #   MixedInputs.new.execute(:a, :b)              # => [:a, :b, []]
  #   MixedInputs.new.execute(:a, :b, 1, 2, 3)     # => [:a, :b, [1,2,3]]
  #
  # Tasks may be create with new, or with intern.  Intern overrides
  # process with a custom block that gets called with the task instance
  # and the inputs.
  #
  #   no_inputs = Task.intern {|task| [] }
  #   one_input = Task.intern {|task, input| [input] }
  #   mixed_inputs = Task.intern {|task, a, b, *args| [a, b, args] }
  #
  #   no_inputs.execute                             # => []
  #   one_input.execute(:a)                         # => [:a]
  #   mixed_inputs.execute(:a, :b)                  # => [:a, :b, []]
  #   mixed_inputs.execute(:a, :b, 1, 2, 3)         # => [:a, :b, [1,2,3]]
  #
  # === Configuration 
  #
  # Tasks are configurable.  By default each task will be configured as 
  # specified in the class definition.  Configurations may be accessed
  # through config, or through accessors.
  #
  #   class ConfiguredTask < Tap::Task
  #     config :one, 'one'
  #     config :two, 'two'
  #   end
  # 
  #   t = ConfiguredTask.new
  #   t.config                     # => {:one => 'one', :two => 'two'}
  #   t.one                        # => 'one'
  #   t.one = 'ONE'
  #   t.config                     # => {:one => 'ONE', :two => 'two'}
  #
  # Overrides and even unspecified configurations may be provided during
  # initialization.  Unspecified configurations do not have accessors.
  #
  #   t = ConfiguredTask.new(:one => 'ONE', :three => 'three')
  #   t.config                     # => {:one => 'ONE', :two => 'two', :three => 'three'}
  #   t.respond_to?(:three)        # => false
  #
  # Configurations can be validated/transformed using an optional block.  
  # Tap::Support::Validation pre-packages many common blocks which may
  # be accessed through the class method 'c':
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
  #--
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
      # Returns class dependencies
      attr_reader :dependencies
      
      # Sets the class default_name
      attr_writer :default_name
      
      # Returns the default name for the class: to_s.underscore
      def default_name
        # lazy-setting default_name like this (rather than
        # within inherited, for example) is an optimization
        # since many subclass operations end up setting
        # default_name themselves.
        @default_name ||= to_s.underscore
      end
      
      # Returns an instance of self; the instance is a kind of 'global'
      # instance used in class-level dependencies.  See depends_on.
      def instance
        @instance ||= new
      end
      
      def inherited(child) # :nodoc:
        unless child.instance_variable_defined?(:@source_file)
          caller.first =~ Support::Lazydoc::CALLER_REGEXP
          child.instance_variable_set(:@source_file, File.expand_path($1)) 
        end

        child.instance_variable_set(:@dependencies, dependencies.dup)
        super
      end
      
      # Instantiates a new task with the input arguments and overrides
      # process with the block.  The block will be called with the 
      # instance, plus any inputs.
      #
      # Simply instantiates a new task if no block is given.
      def intern(*args, &block) # :yields: task, inputs...
        instance = new(*args)
        if block_given?
          instance.extend Support::Intern
          instance.process_block = block
        end
        instance
      end
      
      # Parses the argv into an instance of self and an array of arguments 
      # (implicitly to be enqued to the instance).  Yields a help string to
      # the block when the argv indicates 'help'.
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
          prg = case $0
          when /rap$/ then 'rap'
          else 'tap run --'
          end
          
          opts.banner = "#{help}usage: #{prg} #{to_s.underscore} #{args.subject}"
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
        
        [obj, (argv + use_args)]
      end
      
      # A convenience method to parse the argv and execute the instance
      # with the remaining arguments.  If 'help' is specified in the argv, 
      # execute prints the help and exits.
      def execute(argv=ARGV)
        instance, args = parse(ARGV) do |help|
          puts help
          exit
        end

        instance.execute(*args)
      end
      
      # Returns the class lazydoc, resolving if specified.
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
      # Returns the class help.
      def help
        Tap::Support::Templater.new(DEFAULT_HELP_TEMPLATE, :task_class => self).build
      end
      
      protected
      
      # Sets a class-level dependency.  When task class B depends_on another task 
      # class A, instances of B are initialized to depend on A.instance, with the
      # specified arguments.  Returns self.
      def depends_on(name, dependency_class)
        unless dependencies.include?(dependency_class)
          dependencies << dependency_class
        end
        
        # returns the resolved result of the dependency
        define_method(name) do
          instance = dependency_class.instance
          instance.resolve
          instance._result._current
        end
        
        public(name)
        self
      end
      
      # Defines a task subclass with the specified configurations and process block.
      # During initialization the subclass is instantiated and made accessible 
      # through a reader by the specified name.  
      #
      # Defined tasks may be configured during initialization, through config, or 
      # directly through the instance; in effect you get tasks with nested configs 
      # which greatly facilitates workflows.  Indeed, defined tasks are often 
      # joined in the workflow method.
      #
      #   class AddALetter < Tap::Task
      #     config :letter, 'a'
      #     def process(input); input << letter; end
      #   end
      #
      #   class AlphabetSoup < Tap::Task
      #     define :a, AddALetter, {:letter => 'a'}
      #     define :b, AddALetter, {:letter => 'b'}
      #     define :c, AddALetter, {:letter => 'c'}
      #
      #     def workflow
      #       a.sequence(b, c)
      #     end
      # 
      #     def process
      #       a.execute("")
      #     end
      #   end
      #
      #   AlphabetSoup.new.process            # => 'abc'
      #
      #   i = AlphabetSoup.new(:a => {:letter => 'x'}, :b => {:letter => 'y'}, :c => {:letter => 'z'})
      #   i.process                           # => 'xyz'
      #
      #   i.config[:a] = {:letter => 'p'}
      #   i.config[:b][:letter] = 'q'
      #   i.c.letter = 'r'
      #   i.process                           # => 'pqr'
      #
      # ==== Usage
      #
      # Define is basically the equivalent of:
      #
      #   class Sample < Tap::Task
      #     Name = baseclass.subclass(config, &block)
      #     
      #     # accesses an instance of Name
      #     attr_reader :name
      #
      #     # register name as a config, but with a
      #     # non-standard reader and writer
      #     config :name, {}, {:reader => :name_config, :writer => :name_config=}.merge(options)
      #
      #     # reader for name.config
      #     def name_config; ...; end
      #
      #     # reconfigures name with input
      #     def name_config=(input); ...; end
      #
      #     def initialize(*args)
      #       super
      #       @name = Name.new(config[:name])
      #     end
      #   end
      #
      # Note the following:
      # * define will set a constant like name.camelize
      # * the block defines the process method in the subclass
      # * three methods are created by define: name, name_config, name_config=
      #
      def define(name, baseclass=Tap::Task, configs={}, options={}, &block)
        # define the subclass
        const_name = options.delete(:const_name) || name.to_s.camelize
        subclass = const_set(const_name, Class.new(baseclass))
        subclass.default_name = name.to_s
        
        configs.each_pair do |key, value|
          subclass.send(:config, key, value)
        end
        
        if block_given?
          subclass.send(:define_method, :process, &block)
        end
        
        # define methods
        instance_var = "@#{name}".to_sym
        reader = (options[:reader] ||= "#{name}_config".to_sym)
        writer = (options[:writer] ||= "#{name}_config=".to_sym)
        
        attr_reader name
        
        define_method(reader) do
          # return the config for the instance
          instance_variable_get(instance_var).config
        end
        
        define_method(writer) do |value|
          # initialize or reconfigure the instance of subclass
          if instance_variable_defined?(instance_var) 
            instance_variable_get(instance_var).reconfigure(value)
          else
            instance_variable_set(instance_var, subclass.new(value))
          end
        end
        public(name, reader, writer)
        
        # add the configuration
        if options[:desc] == nil
          caller[0] =~ Support::Lazydoc::CALLER_REGEXP
          desc = Support::Lazydoc.register($1, $3.to_i - 1, Support::Lazydoc::Definition)
          desc.subclass = subclass
          options[:desc] = desc
        end
        
        configurations.add(name, subclass.configurations.instance_config, options)
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

    # Initializes a new Task.
    def initialize(config={}, name=nil, app=App.instance)
      super()

      @name = name || self.class.default_name
      @app = app
      @_method_name = :execute_with_callbacks
      @on_complete_block = nil
      @dependencies = []
      @batch = [self]
      
      case config
      when Support::InstanceConfiguration
        # update is prudent to ensure all configs have an input
        # (and hence, all configs will be initialized)
        @config = config.update(self.class.configurations)
        config.bind(self)
      else 
        initialize_config(config)
      end
      
      self.class.dependencies.each do |dependency_class|
        depends_on(dependency_class.instance)
      end
      
      workflow
    end
    
    # Creates a new batched object and adds the object to batch. The batched
    # object will be a duplicate of the current object but with a new name 
    # and/or configurations.
    def initialize_batch_obj(overrides={}, name=nil)
      obj = super().reconfigure(overrides)
      obj.name = name if name
      obj 
    end
    
    # The method for processing inputs into outputs.  Override this method in
    # subclasses to provide class-specific process logic.  The number of 
    # arguments specified by process corresponds to the number of arguments
    # the task should have when enqued or executed.  
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
    # By default, process simply returns the inputs.
    def process(*inputs)
      inputs
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
    
    # execute_with_callbacks is the method called by _execute
    def execute_with_callbacks(*inputs) # :nodoc:
      before_execute
      begin
        result = process(*inputs)
      rescue
        on_execute_error($!)
      end
      after_execute
       
      result
    end
    
  end
end