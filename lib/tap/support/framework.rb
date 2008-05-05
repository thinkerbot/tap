module Tap
  module Support
    
    # Framework encapsulates the basic framework functionality (batching,
    # configuration, documentation, etc) used by Task and Workflow.
    module Framework
      include Batchable
      include Configurable
    
      def self.included(mod)
        mod.instance_variable_set(:@source_files, [])
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
        
        config.symbolize_keys! unless config.empty?
        app.each_config_template(config_file) do |template|
          template_config = template.empty? ? config : template.symbolize_keys.merge(config)
          initialize_batch_obj(name, template_config)
        end
      end
    
      # Creates a new batched object and adds the object to batch. The batched object 
      # will be a duplicate of the current object but with a new name and/or 
      # configurations.
      def initialize_batch_obj(name=nil, config={})
        obj = super()
      
        obj.name = name.nil? ? self.class.default_name : name
        obj.config = config

        obj
      end
      
      def enq(*inputs)
        raise NotImplementedError, "enq is an abstract method"
      end
      
      def on_complete(override=false, &block)
        raise NotImplementedError, "on_complete is an abstract method"
      end
    
      protected
    
      attr_writer :name

    end
  end
end