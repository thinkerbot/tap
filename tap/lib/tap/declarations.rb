require 'tap/workflow'
require 'tap/env'
require 'tap/declarations/description'

module Tap
  module Declarations
    def self.extended(base)
      base.instance_variable_set(:@desc, nil)
      base.instance_variable_set(:@namespace, Object)
    end
    
    # Sets the description for use by the next task declaration.
    def desc(str)
      @desc = Lazydoc.register_caller(Description)
      @desc.desc = str
      @desc
    end
    
    # Nests tasks within the named module for the duration of the block.
    # Namespaces may be nested.
    def namespace(name)
      previous_namespace = @namespace
      begin
        const_name = name.to_s.camelize
        @namespace = Env::Constant.constantize(const_name, previous_namespace) do |base, constants|
          constants.inject(base) {|current, const| current.const_set(const, Module.new) }
        end
        
        yield
      ensure
        @namespace = previous_namespace
      end
    end
    
    def declare(clas, name, configs={}, &block)
      const_name = name.to_s.camelize
      subclass = Class.new(env.constant(clas))
      @namespace.const_set(const_name, subclass)
      
      # define configs
      convert_to_yaml = Configurable::Validation.yaml
      configs.each_pair do |key, value|
        # specifying a desc prevents lazydoc registration of these lines
        opts = {:desc => ""}
        opts[:short] = key if key.to_s.length == 1
        subclass.send(:config, key, value, opts, &convert_to_yaml)
      end
      
      # define process
      if block
        # prevents assessment of process args by lazydoc
        subclass.const_attrs[:process] = '*args'
        subclass.send(:define_method, :process) {|*args| block.call(self, *args) }
      end
      
      # register documentation
      @desc ||= Lazydoc.register_caller(Description)
      subclass.desc = @desc
      
      # register subclass
      source_file = @desc.document.source_file
      type = File.basename(source_file).chomp(File.extname(source_file))
      constant = env.set(subclass, nil)
      constant.register_as(type, @desc)
      
      @desc = nil
      subclass
    end
    
    def task(name, configs={}, &block)
      @desc ||= Lazydoc.register_caller(Description)
      declare(Tap::Task, name, configs, &block)
    end
    
    def workflow(name, configs={}, &block)
      @desc ||= Lazydoc.register_caller(Description)
      declare(Tap::Workflow, name, configs, &block)
    end
  end
end