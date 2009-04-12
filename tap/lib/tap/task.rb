require 'tap/app'
require 'tap/joins'
require 'tap/root'

autoload(:ConfigParser, 'config_parser')

module Tap
  module Support
    autoload(:Templater, 'tap/support/templater')
    autoload(:Intern, 'tap/support/intern')
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
    include App::Node
    
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
        @instance ||= new.extend(App::Dependency)
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
      # (implicitly to be enqued to the instance).  By default parse 
      # parses an argh then calls instantiate, but there is no requirement
      # that this occurs.
      def parse(argv=ARGV)
        parse!(argv.dup)
      end
      
      # Same as parse, but removes switches destructively.
      def parse!(argv=ARGV)
        instantiate(parse_argh(argv))
      end
      
      def parse_argh(argv=ARGV)
        parse_argh!(argv.dup)
      end
      
      def parse_argh!(argv=ARGV)
        opts = ConfigParser.new
        
        unless configurations.empty?
          opts.separator "configurations:"
          opts.add(configurations)
          opts.separator ""
        end
        
        opts.separator "options:"
        
        # add option to print help
        opts.on("--help", "Print this help") do
          prg = case $0
          when /rap$/ then 'rap'
          else 'tap run --'
          end
          
          puts "#{help}usage: #{prg} #{to_s.underscore} #{args}"
          puts          
          puts opts
          exit
        end
 
        # add option to specify the task name
        name = default_name
        opts.on('--name NAME', 'Specifies the task name') do |value|
          name = value
        end
        
        # add option to specify a config file
        config_file = nil
        opts.on('--config FILE', 'Specifies a config file') do |value|
          config_file = value
        end
        
        # parse!
        argv = opts.parse!(argv, {}, false)
        
        { :name => name,
          :config => opts.nested_config,
          :config_file => config_file,
          :args => argv
        }
      end
      
      def instantiate(argh={})
        name = argh[:name]
        config = argh[:config]
        config_file = argh[:config_file]
        args = argh[:args] || []
        
        instance = new({}, name)
        instance.reconfigure(load_config(config_file)) if config_file
        instance.reconfigure(config) if config
        [instance, args]
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
      def load_config(path)
        # optimization to check for trivial paths
        return {} if Root::Utils.trivial?(path)
        
        Configurable::Utils.load_file(path, true) do |base, key, value|
          base[key] ||= value if base.kind_of?(Hash)
        end
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
        
        # update instance with the dependency if necessary
        if instance_variable_defined?(:@instance)
          instance.depends_on(dependency_class.instance)
        end
        
        if name
          # returns the resolved result of the dependency
          define_method(name) do
            dependency_class.instance.resolve
          end
        
          public(name)
        end
        
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
        subclass = Class.new(baseclass)
        subclass.default_name = name.to_s
        
        configs.each_pair do |key, value|
          subclass.send(:config, key, value)
        end
        
        if block_given?
          # prevent lazydoc registration of the process method
          subclass.registered_methods.delete(:process)
          subclass.send(:define_method, :process, &block)
        end
        
        # register documentation
        # TODO: register subclass in documentation
        options[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer, 1)
        
        # add the configuration
        nest(name, subclass, {:const_name => name.to_s.camelize}.merge!(options))
      end
    end
    
    instance_variable_set(:@source_file, __FILE__)
    instance_variable_set(:@default_name, 'tap/task')
    instance_variable_set(:@dependencies, [])
    
    lazy_attr :manifest
    lazy_attr :args, :process
    lazy_register :process, Lazydoc::Arguments
    
    # The name of self
    #--
    # Currently names may be any object.  Audit makes use of name
    # via to_s, as does app when figuring configuration filepaths. 
    attr_accessor :name

    # Initializes a new Task.
    def initialize(config={}, name=nil)
      @name = name || self.class.default_name
      @app = nil
      @join = nil
      @dependencies = []
      
      # initialize configs
      initialize_config(config)
      
      # setup class dependencies
      self.class.dependencies.each do |dependency_class|
        depends_on(dependency_class.instance)
      end
    end
    
    def call(*_inputs)
      inputs = _inputs.collect {|_input| _input.value }
      process(*inputs)
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
      app.log(action, msg, level) if app
    end
    
    # Sets a sequence workflow pattern for the tasks; each task
    # enques the next task with it's results, starting with self.
    def sequence(*tasks) # :yields: _result
      options = tasks[-1].kind_of?(Hash) ? tasks.pop : {}
      
      current_task = self
      tasks.each do |next_task|
        Join.new(options).join([current_task], [next_task])
        current_task = next_task
      end
    end

    # Sets a fork workflow pattern for self; each target will enque the
    # results of self.
    def fork(*targets) # :yields: _result
      options = targets[-1].kind_of?(Hash) ? targets.pop : {}
      Join.new(options).join([self], targets)
    end

    # Sets a simple merge workflow pattern for the source tasks. Each 
    # source enques self with it's result; no synchronization occurs, 
    # nor are results grouped before being enqued.
    def merge(*sources) # :yields: _result
      options = sources[-1].kind_of?(Hash) ? sources.pop : {}
      Join.new(options).join(sources, [self])
    end

    # Sets a synchronized merge workflow for the source tasks.  Results 
    # from each source are collected and enqued as a single group to
    # self.  The collective results are not enqued until all sources
    # have completed.  See Joins::SyncMerge.
    def sync_merge(*sources) # :yields: _result
      options = sources[-1].kind_of?(Hash) ? sources.pop : {}
      Joins::SyncMerge.new(options).join(sources, [self])
    end

    # Sets a switch workflow pattern for self.  On complete, switch yields
    # the audited result to the block and the block should return the index
    # of the target to enque with the results. No target will be enqued if
    # the index is false or nil.  An error is raised if no target can be
    # found for the specified index. See Joins::Switch.
    def switch(*targets, &block) # :yields: _result
      options = targets[-1].kind_of?(Hash) ? targets.pop : {}
      Joins::Switch.new(options).join([self], targets, &block)
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
  end
end