require 'tap/task'
require 'tap/env'
require 'ostruct'
require 'rap/description'

module Rap
  
  # DeclarationTasks are a special breed of Tap::Task designed to behave much
  # like Rake tasks.  As such, declaration tasks:
  #
  # * return nil and pass nil in workflows 
  # * only execute once
  # * are effectively singletons (one instance per app)
  # * allow for multiple actions
  #
  # The DeclarationTask class partially includes Declarations so subclasses
  # may directly declare tasks.  A few alias acrobatics makes it so that ONLY
  # Declarations#task is made available (desc cannot be used because Task
  # classes already use that method for documentation, and namespace
  # would be silly).
  #
  # Weird? Yes, but it leads to this syntax:
  #
  #   # [Rapfile]
  #   # class Subclass < Rap::DeclarationTask
  #   #   def helper(); "help"; end
  #   # end
  #   #
  #   # # ::desc a help task
  #   # Subclass.task(:help) {|task, args| puts "got #{task.helper}"}
  #   
  #   % rap help
  #   got help
  #
  class DeclarationTask < Tap::Task
    class << self
      
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
      
      # Instantiates the instance of self for app and reconfigures it using
      # argh.  Configurations are set, the task name is set, and the
      # arguments are stored on the instance.  The arguments are returned
      # as normal in the [instance, args] result.
      #
      # These atypical behaviors handle various situations on the command
      # line.  Setting the args this way, for example, allows arguments to
      # be specified on dependency tasks:
      #
      #   # [Rapfile]
      #   # Rap.task(:a, :obj) {|t, a| puts "A #{a.obj}"}
      #   # Rap.task({:b => :a}, :obj) {|t, a| puts "B #{a.obj}"}
      #
      #   % rap b world -- a hello
      #   A hello
      #   B world
      #
      def instantiate(argh={}, app=Tap::App.instance)
        config = argh[:config]
        config_file = argh[:config_file]
        
        instance = self.instance(app)
        instance.reconfigure(load_config(config_file)) if config_file
        instance.reconfigure(config) if config
        
        instance.name = argh[:name]
        instance.args = argh[:args]
        
        [instance, instance.args]
      end
      
      # Looks up or creates the DeclarationTask subclass specified by const_name
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
            namespace.const_set(const, Class.new(DeclarationTask))
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
          dependency_name = File.basename(dependency.default_name)
          
          # this suppresses 'method redefined' warnings
          if subclass.method_defined?(dependency_name)
            subclass.send(:undef_method, dependency_name)
          end
          
          subclass.send(:depends_on, dependency_name, dependency)
        end
        
        subclass
      end
    end
    
    # The result of self, set by call.
    attr_reader :result
    
    # The arguments assigned to self during call.
    attr_accessor :args
    
    def initialize(config={}, name=nil, app=Tap::App.instance)
      super
      @resolved = false
      @result = nil
      @args = nil
    end
    
    # Conditional call to the super call; only calls once.  Returns result.
    def call(*args)
      
      # Declaration tasks function as dependencies, but unlike normal
      # dependencies, they CAN take arguments from the command line.
      # Such arguments will be set as args, and be used to enque the
      # task.  
      #
      # If the task executes from the queue first, args will be
      # provided to call and they should equal self.args.  If the task
      # executes as a dependency first, call will not receive args and
      # in that case self.args will be used.
      #
      # This warns for cases that odd workflows can produce where the
      # args have been set and DIFFERENT args are used to enque the task.
      # In these cases always go with the pre-set args but warn the issue.
      self.args ||= args
      unless self.args == args
        if @resolved
          warn "warn: ignorning dependency task inputs #{args.inspect} (#{self})"
        else
          warn "warn: invoking dependency task with preset args #{self.args.inspect} and not inputs #{args.inspect} (#{self})"
        end
      end
      
      unless @resolved
        @resolved = true
        @result = super(*self.args)
      end
      result
    end
    
    # Returns true if already resolved by call.
    def resolved?
      @resolved
    end
    
    # Resets self so call will call again.  Also sets result to nil.
    def reset
      @resolved = false
      @result = nil
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
  end
end