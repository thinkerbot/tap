require 'tap/app/api'

module Tap
  
  # Tasks are nodes that map to the command line.  Tasks provide support for
  # configuration, documentation, and provide helpers to build workflows.
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
    class << self
      def parser(app)
        opts = super
        
        # add option to specify a config file
        opts.on('--config FILE', 'Specifies a config file') do |config_file|
          configs = Configurable::Utils.load_file(config_file, true)
          opts.config.merge!(configs)
        end
        
        opts
      end
    end
    
    lazy_attr :args, :process
    lazy_register :process, Lazydoc::Arguments
    
    attr_reader :app
    attr_reader :joins
    
    signal :enq
    signal :exe
    
    def initialize(config={}, app=Tap::App.current)
      @app = app
      @joins = []
      initialize_config(config)
    end
    
    def associations
      [nil, joins]
    end
    
    def call(inputs)
      process(*inputs)
    end
    
    def process(*inputs)
      inputs
    end
    
    def enq(*args)
      app.enq(self, args)
    end
    
    def exe(*inputs)
      app.exe(self, inputs)
    end
    
    # Logs the inputs to the application logger (via app.log)
    def log(action, msg=nil, level=Logger::INFO)
      app.log(action, msg, level) { yield }
    end
    
    # Sets the block as a join for self.
    def on_complete(&block) # :yields: result
      joins << block if block
      self
    end
    
    # Provides an abbreviated version of the default inspect, with only
    # the task class, object_id, and configurations listed.
    def inspect
      "#<#{self.class.to_s}:#{object_id} #{config.to_hash.inspect} >"
    end
  end
end