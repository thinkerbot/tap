require 'tap/joins'
require 'tap/root'
require 'tap/env/string_ext'

module Tap
  class App
    # Generates a task with the specified config, initialized to self.
    #
    # A block may be provided to overrride the process method; it will be
    # called with the task instance, plus any inputs.
    #
    #   no_inputs = app.task {|task| [] }
    #   one_input = app.task {|task, input| [input] }
    #   mixed_inputs = app.task {|task, a, b, *args| [a, b, args] }
    #
    #   no_inputs.execute                            # => []
    #   one_input.execute(:a)                        # => [:a]
    #   mixed_inputs.execute(:a, :b)                 # => [:a, :b, []]
    #   mixed_inputs.execute(:a, :b, 1, 2, 3)        # => [:a, :b, [1,2,3]]
    #
    def task(config={}, klass=Task, &block)
      instance = klass.new(config, self)
      if block_given?
        instance.extend Intern
        instance.process_block = block
      end
      instance
    end
  end
  
  # Tasks are nodes that map to the command line.  Tasks provide support for
  # configuration, documentation, and provide helpers to build workflows.
  #
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
  #   t.string = 1                 # !> ValidationError
  #   t.integer = 1.1              # !> ValidationError
  #
  #   t.integer = "1"
  #   t.integer == 1               # => true 
  #
  # See the {Configurable}[http://tap.rubyforge.org/configurable/]
  # documentation for more information.
  #
  # === Subclassing
  #
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
  class Task < App::Api
    include App::Node
    
    class << self

      # Same as parse, but removes arguments destructively.
      def parse!(argv=ARGV, app=Tap::App.instance) # :yields: opts
        opts = ConfigParser.new
        
        unless configurations.empty?
          opts.separator "configurations:"
          opts.add(configurations)
          opts.separator ""
        end
        
        opts.separator "options:"
        
        # add option to print help
        opts.on("--help", "Print this help") do
          lines = desc.kind_of?(Lazydoc::Comment) ? desc.wrap(77, 2, nil) : []
          lines.collect! {|line| "  #{line}"}
          unless lines.empty?
            line = '-' * 80
            lines.unshift(line)
            lines.push(line)
          end

          puts "#{self}#{desc.empty? ? '' : ' -- '}#{desc.to_s}"
          puts help
          puts "usage: tap run -- #{to_s.underscore} #{args}"
          puts          
          puts opts
          exit
        end
        
        # add option to specify a config file
        opts.on('--config FILE', 'Specifies a config file') do |config_file|
          opts.config.merge!(load_config(config_file))
        end
        
        yield(opts) if block_given?
        
        # (note defaults are not added so they will not
        # conflict with string keys from a config file)
        argv = opts.parse!(argv, :add_defaults => false)
        
        [build({'config' => opts.nested_config}, app), argv]
      end
      
      # Recursively loads path into a nested configuration file.
      def load_config(path) # :nodoc:
        # optimization to check for trivial paths
        return {} if Root::Utils.trivial?(path)
        
        Configurable::Utils.load_file(path, true) do |base, key, value|
          base[key] ||= value if base.kind_of?(Hash)
        end
      end
      
      protected
      
      # Defines a task subclass with the specified configurations and process
      # block. During initialization the subclass is instantiated and made
      # accessible through the name method.  
      #
      # Defined tasks may be configured during through config, or directly
      # through the instance; in effect you get tasks with nested configs which
      # can greatly facilitate workflows.
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
      #     def initialize(*args)
      #       super
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
    
    lazy_attr :args, :process
    lazy_register :process, Lazydoc::Arguments
    
    ###############################################################
    # [depreciated] manifest will be removed at 1.0
    lazy_attr :manifest
    def self.desc(resolve=true)
      comment = const_attrs['task'] ||= self.manifest
      resolve && comment.kind_of?(Lazydoc::Comment) ? comment.resolve : comment
    end
    def self.manifest
      # :::-
      #"warn manifest is depreciated, use ::task instead"
      # :::+
      const_attrs['manifest'] ||= Lazydoc::Subject.new(nil, lazydoc)
    end
    ###############################################################
    
    signal :enq
    
    # The App receiving self during enq
    attr_reader :app

    # Initializes a new Task.
    def initialize(config={}, app=Tap::App.instance)
      @app = app
      @joins = []
      
      # initialize configs
      initialize_config(config)
    end
    
    # Auditing method call.  Resolves dependencies, executes method_name,
    # and sends the audited result to the on_complete_block (if set).
    #
    # Returns the audited result.
    def execute(*inputs)
      app.dispatch(self, inputs)
    end
    
    def call(*inputs)
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
    #   results = []
    #   app = Tap::App.new {|result| results << result }
    #
    #   t = TaskWithTwoInputs.new({}, app)
    #   t.enq(1,2).enq(3,4)
    #   
    #   app.run
    #   results                 # => [[2,1], [4,3]]
    #
    # By default, process simply returns the inputs.
    def process(*inputs)
      inputs
    end
    
    # Enqueues self to app with the inputs. The number of inputs provided
    # should match the number of inputs for the method_name method.
    def enq(*inputs)
      app.queue.enq(self, inputs)
      self
    end
    
    # Sets a sequence workflow pattern for the tasks; each task
    # enques the next task with it's results, starting with self.
    def sequence(*tasks)
      options = tasks[-1].kind_of?(Hash) ? tasks.pop : {}
      
      current_task = self
      tasks.each do |next_task|
        Join.new(options, app).join([current_task], [next_task])
        current_task = next_task
      end
    end

    # Sets a fork workflow pattern for self; each target will enque the
    # results of self.
    def fork(*targets)
      options = targets[-1].kind_of?(Hash) ? targets.pop : {}
      Join.new(options, app).join([self], targets)
    end

    # Sets a simple merge workflow pattern for the source tasks. Each 
    # source enques self with it's result; no synchronization occurs, 
    # nor are results grouped before being enqued.
    def merge(*sources)
      options = sources[-1].kind_of?(Hash) ? sources.pop : {}
      Join.new(options, app).join(sources, [self])
    end

    # Sets a synchronized merge workflow for the source tasks.  Results 
    # from each source are collected and enqued as a single group to
    # self.  The collective results are not enqued until all sources
    # have completed.  See Joins::Sync.
    def sync_merge(*sources)
      options = sources[-1].kind_of?(Hash) ? sources.pop : {}
      Joins::Sync.new(options, app).join(sources, [self])
    end

    # Sets a switch workflow pattern for self.  On complete, switch yields
    # the result to the block and the block should return the index of the
    # target to enque with the results. No target will be enqued if the
    # index is false or nil.  An error is raised if no target can be found
    # for the specified index. See Joins::Switch.
    def switch(*targets, &block) # :yields: result
      options = targets[-1].kind_of?(Hash) ? targets.pop : {}
      Joins::Switch.new(options, app).join([self], targets, &block)
    end
    
    # Logs the inputs to the application logger (via app.log)
    def log(action, msg=nil, level=Logger::INFO)
      app.log(action, msg, level) { yield }
    end
    
    # Provides an abbreviated version of the default inspect, with only
    # the task class, object_id, and configurations listed.
    def inspect
      "#<#{self.class.to_s}:#{object_id} #{config.to_hash.inspect} >"
    end
  end
end