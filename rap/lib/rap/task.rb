require 'tap/task'
require 'tap/utils'
require 'ostruct'

module Rap
  
  # Rap tasks are a special breed of Tap::Task designed to behave much
  # like Rake tasks.  As such, declaration tasks:
  #
  # * return nil and pass nil in workflows 
  # * only execute once
  # * are effectively singletons (one instance per app)
  # * allow for multiple actions
  #
  # The Rap::Task class partially includes Declarations so subclasses
  # may directly declare tasks.  A few alias acrobatics makes it so that ONLY
  # Declarations#task is made available (desc cannot be used because Task
  # classes already use that method for documentation, and namespace
  # would be silly).
  #
  # Weird? Yes, but it leads to this syntax:
  #
  #   # [Rapfile]
  #   # class Subclass < Rap::Task
  #   #   def helper(); "help"; end
  #   # end
  #   #
  #   # # :: a help task
  #   # Subclass.task(:help) {|task, args| puts "got #{task.helper}"}
  #   
  #   % rap help
  #   got help
  #
  class Task < Tap::Task
    class << self
      
      # Returns class dependencies
      attr_reader :dependencies

      # Returns or initializes the instance of self cached with app.
      def instance(app=Tap::App.instance, auto_initialize=true)
        app.objects[self] ||= (auto_initialize ? new({}, app) : nil)
      end

      def inherited(child) # :nodoc:
        child.instance_variable_set(:@dependencies, dependencies.dup)
        super
      end
      
      # Sets actions.
      attr_writer :actions
      
      # An array of actions (blocks) associated with this class.  Each of the
      # actions is called during process, with the instance and any args
      # passed to process organized into an OpenStruct.
      def actions
        @actions ||= []
      end
      
      # Sets argument names
      attr_writer :arg_names
      
      # The argument names pulled from a task declaration.
      def arg_names
        @arg_names ||= []
      end
      
      # Returns a Lazydoc::Arguments constructed from arg_names.
      def args
        args = Lazydoc::Arguments.new
        arg_names.each {|name| args.arguments << name.to_s }
        args
      end
      
      # Instantiates the instance of self for app and reconfigures it as
      # specified in argh.
      def build(argh={}, app=Tap::App.instance)
        instance = self.instance(app)
        
        if config = argh['config']
          instance.reconfigure(config)
        end
        
        if args = argh['args']
          instance.args = args
        end
        
        instance
      end
      
      # Sets a class-level dependency; when task class B depends_on another
      # task class A, instances of B are initialized to depend on a shared
      # instance of A.  The shared instance is specific to an app and can
      # be accessed through instance(app).
      #
      # If a non-nil name is specified, depends_on will create a reader of 
      # the dependency instance.
      #
      #   class A < Rap::Task
      #   end
      #
      #   class B < Rap::Task
      #     depends_on :a, A
      #   end
      #
      #   app = Tap::App.new
      #   b = B.new({}, app)
      #   b.dependencies           # => [A.instance(app)]
      #   b.a                      # => A.instance(app)
      #
      # Returns self.
      def depends_on(name, dependency_class)
        unless dependency_class.ancestors.include?(Rap::Task)
          raise "not a Rap::Task: #{dependency_class}"
        end
        
        unless dependencies.include?(dependency_class)
          dependencies << dependency_class
        end
        
        if name
          # returns the resolved result of the dependency
          define_method(name) do
            dependency_class.instance(app)
          end
        
          public(name)
        end
        
        self
      end
      
      protected
      
      def convert_to_spec(parser, args) # :nodoc:
        {'config' => parser.nested_config, 'args' => args}
      end
    end
    
    # This sets the class-level dependencies array.
    @dependencies = []
    
    # An array of node dependencies
    attr_reader :dependencies
    
    # The arguments assigned to self.
    attr_accessor :args
    
    def initialize(config={}, app=Tap::App.instance)
      super
      @dependencies = []
      @resolved = false
      @args = nil
      
      # setup class dependencies
      self.class.dependencies.each do |dependency_class|
        depends_on dependency_class.instance(app)
      end
    end
    
    # Conditional call to the super call; only calls once and with args (if
    # set).  Call recursively resolves dependencies and raises an error for
    # circular dependencies.
    #
    def call(inputs=nil)
      if resolved?
        return
      end
      
      if resolving?
        raise DependencyError.new(self)
      end
      
      @resolved = nil
      begin
        dependencies.each do |dependency|
          dependency.call(nil)
        end
      rescue(DependencyError)
        $!.trace.unshift(self)
        raise $!
      end

      @resolved = true
      args ? process(*args) : process()
      inputs
    end
    
    # Alias for call.
    def resolve!
      call
    end

    # Returns true if already resolved by call.
    def resolved?
      @resolved == true
    end
    
    def resolving?
      @resolved == nil
    end
    
    # Resets self so call will call again.  Also sets result to nil.
    def reset
      raise "cannot reset when resolving" if resolving?
      @resolved = false
    end
    
    # Collects the inputs into an OpenStruct according to the class arg_names,
    # and calls each class action in turn.  This behavior echoes the behavior
    # of Rake tasks.
    def process(*inputs)
      # collect inputs to make a rakish-args object
      args = {}
      self.class.arg_names.each do |arg_name|
        break if inputs.empty?
        args[arg_name] = inputs.shift
      end
      args = OpenStruct.new(args)
      
      # execute each block assciated with this task
      self.class.actions.each do |action|
        case action.arity
        when 0 then action.call()
        when 1 then action.call(self)
        else action.call(self, args)
        end
      end
      
      nil
    end
    
    # Adds the dependency to self.
    def depends_on(dependency)
      raise "cannot depend on self" if dependency == self
      unless dependencies.include?(dependency)
        dependencies << dependency
      end
      self
    end
  end
  
  # Raised for circular dependencies during Rap::Task.resolve!
  class DependencyError < StandardError
    attr_reader :trace
    
    def initialize(task)
      @trace = [task]
      super()
    end
    
    def message
      "circular dependency: [#{trace.collect {|task| task.class.to_s }.join(', ')}]"
    end
  end
end