require 'tap/support/executable'
require 'tap/support/intern'
autoload(:ConfigParser, 'config_parser')

module Tap
  module Support
    autoload(:Templater, 'tap/support/templater')
  end
  
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
  # Tasks may be create with new, or with intern.  Intern overrides process
  # using a block that receives the task instance and the inputs.
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
  # Many common blocks are pre-packaged and may be accessed through the
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
  # See the {Configurable}[http://tap.rubyforge.org/configurable/]
  # documentation for more information.
  #
  # === Subclassing
  # Tasks may be subclassed normally, but be sure to call super as necessary,
  # in particular when overriding the following methods:
  #
  #   class Subclass < Tap::Task
  #     class << self
  #       def inherited(child)
  #         super
  #       end
  #     end
  #
  #     def initialize(*args)
  #       super
  #     end
  #
  #     def initialize_copy(orig)
  #       super
  #     end
  #   end
  #
  class Task
    include Configurable
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
        @instance ||= new.extend(Support::Dependency)
      end
      
      def inherited(child) # :nodoc:
        unless child.instance_variable_defined?(:@source_file)
          caller[0] =~ Lazydoc::CALLER_REGEXP
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
      # (implicitly to be enqued to the instance).
      def parse(argv=ARGV, app=Tap::App.instance)
        parse!(argv.dup)
      end
      
      # Same as parse, but removes switches destructively.
      def parse!(argv=ARGV, app=Tap::App.instance)
        opts = ConfigParser.new
        opts.separator "configurations:"
        opts.add(configurations)
        
        opts.separator ""
        opts.separator "options:"
        
        # Add option to print help
        opts.on("-h", "--help", "Print this help") do
          prg = case $0
          when /rap$/ then 'rap'
          else 'tap run --'
          end
          
          puts "#{help}usage: #{prg} #{to_s.underscore} #{args}"
          puts          
          puts opts
          exit
        end
 
        # Add option to specify a config file
        name = default_name
        opts.on('--name NAME', 'Specify a name') do |value|
          name = value
        end
 
        # Add option to add args
        use_args = []
        opts.on('--use FILE', 'Loads inputs from file') do |path|
          use(path, use_args)
        end
        
        # build and reconfigure the instance and any associated
        # batch objects as specified in the file configurations
        argv = opts.parse!(argv)
        configs = load(app.config_filepath(name))
        configs = [configs] unless configs.kind_of?(Array)
        
        obj = new(configs.shift, name, app)
        configs.each do |config|
          obj.initialize_batch_obj(config, "#{name}_#{obj.batch.length}")
        end        

        obj.batch.each do |batch_obj|
          batch_obj.reconfigure(opts.config)
        end
        
        [obj, (argv + use_args)]
      end
      
      # A convenience method to parse the argv and execute the instance
      # with the remaining arguments.  If 'help' is specified in the argv, 
      # execute prints the help and exits.
      #
      # Returns the non-audited result.
      def execute(argv=ARGV)
        instance, args = parse(ARGV)
        instance.execute(*args)
      end

      DEFAULT_HELP_TEMPLATE = %Q{<% manifest = task_class.manifest %>
<%= task_class %><%= manifest.empty? ? '' : ' -- ' %><%= manifest.to_s %>

<% desc = manifest.kind_of?(Lazydoc::Comment) ? manifest.wrap(77, 2, nil) : [] %>
<% unless desc.empty? %>
<%= '-' * 80 %>

<% desc.each do |line| %>
  <%= line %>
<% end %>
<%= '-' * 80 %>
<% end %>

}
      
      # Returns the class help.
      def help
        Tap::Support::Templater.new(DEFAULT_HELP_TEMPLATE, :task_class => self).build
      end
      
      # Recursively loads path into a nested configuration file.
      #--
      # TODO: move the logic of this to Configurable
      def load(path, recursive=true)
        base = Root.trivial?(path) ? {} : (YAML.load_file(path) || {})
        
        if recursive
          # determine the files/dirs to load recursively
          # and add them to paths by key (ie the base
          # name of the path, minus any extname)
          paths = {}
          files, dirs = Dir.glob("#{path.chomp(File.extname(path))}/*").partition do |sub_path|
            File.file?(sub_path)
          end

          # directories are added to paths first so they can be
          # overridden by the files (appropriate since the file
          # will recursively load the directory if it exists)
          dirs.each do |dir|
            paths[File.basename(dir)] = dir
          end

          # when adding files, check that no two files map to
          # the same key (ex a.yml, a.yaml).
          files.each do |filepath|
            key = File.basename(filepath).chomp(File.extname(filepath))
            if existing = paths[key]
              if File.file?(existing)
                confict = [File.basename(paths[key]), File.basename(filepath)].sort
                raise "multiple files load the same key: #{confict.inspect}"
              end
            end

            paths[key] = filepath
          end

          # recursively load each file and reverse merge
          # the result into the base
          paths.each_pair do |key, recursive_path|
            value = nil
            each_hash_in(base) do |hash|
              unless hash.has_key?(key)
                hash[key] = (value ||= load(recursive_path, true))
              end
            end
          end
        end

        base
      end
      
      # Loads the contents of path onto argv.
      def use(path, argv=ARGV)
        obj = Root.trivial?(path) ? [] : (YAML.load_file(path) || [])
        
        case obj
        when Array then argv.concat(obj)
        else argv << obj
        end
        
        argv
      end
      
      protected
      
      # Sets a class-level dependency; when task class B depends_on another
      # task class A, instances of B are initialized to depend on A.instance.
      # If a non-nil name is specified, depends_on will create a reader of 
      # the resolved dependency value.
      #
      #   class A < Tap::Task
      #     def process
      #       "result"
      #     end
      #   end
      #
      #   class B < Tap::Task
      #     depends_on :a, A
      #   end
      #
      #   b = B.new
      #   b.dependencies           # => [A.instance]
      #   b.a                      # => "result"
      #
      #   A.instance.resolved?     # => true
      # 
      # Normally class-level dependencies are not added to existing instances
      # but, as a special case, depends_on updates instance to depend on
      # dependency_class.instance.
      #
      # Returns self.
      def depends_on(name, dependency_class)
        unless dependencies.include?(dependency_class)
          dependencies << dependency_class
        end
        
        # returns the resolved result of the dependency
        define_method(name) do
          dependency_class.instance.resolve.value
        end if name
        
        if instance_variable_defined?(:@instance)
          instance.depends_on(dependency_class.instance)
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
        
        # add the configuration
        if options[:desc] == nil
          caller[0] =~ Lazydoc::CALLER_REGEXP
          desc = Lazydoc.register($1, $3.to_i - 1)#, Lazydoc::Definition)
          #desc.subclass = subclass
          options[:desc] = desc
        end
        
        nest(name, subclass, options) {|overrides| subclass.new(overrides) }
      end
      
      private
      
      # helper for load_config.  yields each hash in the collection (ie each
      # member of an Array, or the collection if it is a hash). returns
      # the collection.
      def each_hash_in(collection) # :nodoc:
        case collection
        when Hash then yield(collection)
        when Array
          collection.each do |hash|
            yield(hash) if hash.kind_of?(Hash)
          end
        end

        collection
      end
    end
    
    instance_variable_set(:@source_file, __FILE__)
    instance_variable_set(:@default_name, 'tap/task')
    instance_variable_set(:@dependencies, [])
    
    lazy_attr :manifest
    lazy_attr :args, :process
    lazy_register :process, Lazydoc::Arguments
    
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
      @method_name = :execute_with_callbacks
      @on_complete_block = nil
      @dependencies = []
      @batch = [self]
      
      case config
      when DelegateHash
        # update is prudent to ensure all configs have an input
        # (and hence, all configs will be initialized)
        @config = config.update.bind(self)
      else 
        initialize_config(config)
      end
      
      # setup class dependencies
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