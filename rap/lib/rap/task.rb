require 'tap/task'
require 'tap/env'
require 'rap/description'
require 'rap/utils'
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
  #   # # ::desc a help task
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
        app.cache[self] ||= (auto_initialize ? new({}, app) : nil)
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
      
      # Parses as normal, but also stores the arguments on the instance to
      # allows arguments to be specified on dependency tasks:
      #
      #   # [Rapfile]
      #   # Rap.task(:a, :obj) {|t, a| puts "A #{a.obj}"}
      #   # Rap.task({:b => :a}, :obj) {|t, a| puts "B #{a.obj}"}
      #
      #   % rap b world -- a hello
      #   A hello
      #   B world
      #
      def parse!(argv=ARGV, app=Tap::App.instance)
        instance, args = super
        
        # store args on instance and clear so that instance
        # will not be enqued with any inputs
        instance.args = args
        
        [instance, []]
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
      
      # Looks up or creates the Rap::Task subclass specified by const_name
      # and adds the configs and dependencies.
      #
      # Configurations are always validated using the yaml transformation block
      # (see {Configurable::Validation}[http://tap.rubyforge.org/configurable/classes/Configurable/Validation.html]).
      def subclass(const_name, configs={}, dependencies=[])
        # lookup or generate the subclass
        subclass = Tap::Env::Constant.constantize(const_name.to_s) do |base, constants|
          subclass_const = constants.pop
          constants.inject(base) do |namespace, const|
            # nesting Task classes into other Task classes is required
            # for namespaces with the same name as a task
            namespace.const_set(const, Class.new(Rap::Task))
          end.const_set(subclass_const, Class.new(self))
        end

        # check a correct class was found
        unless subclass.ancestors.include?(self)
          raise "not a #{self}: #{subclass}"
        end

        # append configuration (note that specifying a desc 
        # prevents lazydoc registration of these lines)
        convert_to_yaml = Configurable::Validation.yaml
        configs.each_pair do |key, value|
          subclass.send(:config, key, value, :desc => "", &convert_to_yaml)
        end

        # add dependencies
        dependencies.each do |dependency|
          dependency_name = File.basename(dependency.to_s.underscore)
          
          # this suppresses 'method redefined' warnings
          if subclass.method_defined?(dependency_name)
            subclass.send(:undef_method, dependency_name)
          end
          
          subclass.send(:depends_on, dependency_name, dependency)
        end
        
        subclass
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
    def call
      if resolved?
        return
      end
      
      if resolving?
        raise DependencyError.new(self)
      end
      
      @resolved = nil
      begin
        dependencies.each do |dependency|
          dependency.call
        end
      rescue(DependencyError)
        $!.trace.unshift(self)
        raise $!
      end

      @resolved = true
      args ? super(*args) : super()
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