module Tap
  module Support
    
    # Configurable encapsulates all configuration-related methods used
    # by Tasks.  When Configurable is included in a class, the class itself
    # is extended with Tap::Support::ConfigurableMethods, such that configs
    # can be declared within the class definition.
    #
    #   class ConfigurableClass
    #     include Configurable
    # 
    #     config :one, 'one'
    #     config :two, 'two'
    #     config :three, 'three'
    #   end
    #
    #   ConfigurableClass.new.config  # => {:one => 'one', :two => 'two', :three => 'three'}
    #
    # See the 'Configuration' section in the Tap::Task documentation for
    # more details on how Configurable works in practice.
    module Configurable
      include Batchable
    
      def self.included(mod)
        mod.extend Support::BatchableMethods
        mod.extend Support::ConfigurableMethods
        mod.instance_variable_set(:@configurations, Support::ClassConfiguration.new(mod))
        mod.instance_variable_set(:@source_files, [])
      end
    
      # The application used to load config_file templates 
      # (and hence, to initialize batched objects).
      attr_reader :app
      
      # The name used to determine config_file, via
      # app.config_filepath(name).
      attr_reader :name
      
      # The config file used to load config templates.
      attr_reader :config_file
      
      # A configuration hash.
      attr_reader :config
      
      # Initializes a new Configurable and associated batch objects.  Batch
      # objects will be initialized for each configuration template specified
      # in config_file, where config_file = app.config_filepath(name).  
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
    
      # Sets config with the given configuration overrides, merged with the class
      # default configuration.  Configurations are symbolized before they are merged,
      # and validated as specified in the config declarations.
      def config=(overrides)
        @config = self.class.configurations.default.dup
        overrides.each_pair {|key, value| set_config(key.to_sym, value) } 
        self.config
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
    
      protected
    
      attr_writer :name
    
      # Sets the specified configuration, processing the input value using
      # the block specified in the config declaration.  The input key should
      # be symbolized.
      def set_config(key, value)
        config[key] = self.class.configurations.process(key, value)
      end
    end
  end
end