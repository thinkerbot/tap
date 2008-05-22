module Tap
  module Support
    
    # Framework encapsulates the basic framework functionality (batching,
    # configuration, documentation, logging, etc) used by Task and Workflow.  
    # Note that Framework does NOT encapsulate the functionality needed to
    # make a class useful in workflows, such as enq and on_complete.
    module Framework
      include Batchable
      include Configurable
    
      def self.included(mod)
        mod.extend Support::BatchableMethods
        mod.extend Support::ConfigurableMethods
        mod.extend Support::FrameworkMethods
      end
    
      # The application used to load config_file templates 
      # (and hence, to initialize batched objects).
      attr_reader :app
      
      # The name used to determine config_file, via
      # app.config_filepath(name).
      attr_reader :name
      
      # The config file used to load config templates.
      attr_reader :config_file

      # Initializes a new instance and associated batch objects.  Batch
      # objects will be initialized for each configuration template 
      # specified by app.each_config_template(config_file) where 
      # config_file = app.config_filepath(name).  
      def initialize(name=nil, config={}, app=App.instance)
        @app = app
        @batch = []
        @config_file = app.config_filepath(name)
        
        config = config.inject({}) do |options, (key, value)|
          options[key.to_sym || key] = value
          options
        end unless config.empty?

        app.each_config_template(config_file) do |template|
          template_config = if template.empty?
            config
          else
            template = template.inject({}) do |options, (key, value)|
              options[key.to_sym || key] = value
              options
            end
            template.merge(config)
          end
          
          initialize_batch_obj(name, template_config)
        end
      end
    
      # Creates a new batched object and adds the object to batch. The batched object 
      # will be a duplicate of the current object but with a new name and/or 
      # configurations.
      def initialize_batch_obj(name=nil, config={})
        obj = super()
      
        obj.name = name.nil? ? self.class.default_name : name
        obj.initialize_config(config)

        obj
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
        name
      end
      
      protected
    
      attr_writer :name

    end
  end
end