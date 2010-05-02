require 'tap/join'
require 'tap/workflow'
require 'tap/declarations/description'
require 'tap/declarations/context'
require 'tap/parser'
require 'tap/tasks/singleton'

module Tap
  module Declarations
    def env
      app.env
    end
    
    # Returns a new node that executes block on call.
    def node(var=nil, &node) # :yields: *args
      def node.joins; @joins ||= []; end
      app.set(var, node) if var
      node
    end
    
    # Generates a join between the inputs and outputs.  Join resolves the
    # class using env and initializes a new instance with the configs and
    # self. 
    def join(inputs, outputs, config={}, clas=Tap::Join, &block)
      inputs  = [inputs]  unless inputs.kind_of?(Array)
      outputs = [outputs] unless outputs.kind_of?(Array)
      
      obj = app.init(clas, config, app)
      obj.join(inputs, outputs, &block)
      obj
    end
    
    # Sets the description for use by the next task declaration.
    def desc(str)
      @desc = Lazydoc.register_caller(Description)
      @desc.desc = str
      @desc
    end
    
    def singleton(&block)
      baseclass(Tap::Tasks::Singleton, &block)
    end
    
    def baseclass(baseclass=Tap::Task)
      current = @baseclass
      begin
        @baseclass = env.constant(baseclass) unless baseclass.nil?
        yield if block_given?
      ensure
        @baseclass = current if block_given?
      end
    end
    
    # Nests tasks within the named module for the duration of the block.
    # Namespaces may be nested.
    def namespace(namespace)
      current = @namespace
      begin
        unless namespace.nil? || namespace.kind_of?(Module)
          const_name = namespace.to_s.camelize
          unless current.const_defined?(const_name)
            current.const_set(const_name, Module.new)
          end
          namespace = current.const_get(const_name)
        end
        
        @namespace = namespace unless namespace.nil?
        yield if block_given?
      ensure
        @namespace = current if block_given?
      end
    end
    
    def declare(baseclass, const_name, configs={}, &block)
      const_name = const_name.to_s.camelize
      subclass = Class.new(env.constant(baseclass))
      @namespace.const_set(const_name, subclass)
      
      # define configs
      configs.each_pair do |key, value|
        # specifying a desc prevents lazydoc registration of these lines
        opts = {:desc => ""}
        opts[:short] = key if key.to_s.length == 1
        config_block = Configurable::Validation.guess(value)
        subclass.send(:config, key, value, opts, &config_block)
      end
      
      # define process
      if block
        # prevents assessment of process args by lazydoc
        subclass.const_attrs[:process] = '*args'
        subclass.send(:define_method, :process) {|*args| block.call(self, *args) }
      end
      
      # register documentation
      constant = env.set(subclass, nil)
      
      if @desc
        subclass.desc = @desc
        constant.register_as(subclass.type, @desc)
        @desc = nil
      end
      
      subclass
    end
    
    def task(const_name, configs={}, baseclass=@baseclass, &block)
      @desc ||= Lazydoc.register_caller(Description)
      const_name, prerequisites = parse_prerequisites(const_name)

      if prerequisites.nil?
        return declare(baseclass, const_name, configs, &block)
      end

      tasc = work(const_name, configs) do |workflow|
        psr = Parser.new
        args = psr.parse!(prerequisites)
        warn "ignoring args: #{args.inspect}" unless args.empty?
        psr.build_to(app)
        
        obj = init("#{const_name.to_s.underscore}/task", workflow.config.to_hash)
        setup = lambda {|input| exe(obj, input) }
        
        [setup, obj]
      end

      namespace(const_name) do
        declare(baseclass, 'Task', configs, &block)
      end

      tasc
    end

    def work(const_name, configs={}, baseclass=Tap::Workflow, &block)
      @desc ||= Lazydoc.register_caller(Description)
      task(const_name, configs, baseclass, &block)
    end
    
    protected
    
    def initialize_declare(baseclass=Tap::Task, namespace=Object)
      @desc = nil
      @baseclass = baseclass
      @namespace = namespace
    end

    private

    def parse_prerequisites(const_name)
      prerequisites = nil

      if const_name.is_a?(Hash)
        hash = const_name
        case hash.length
        when 0
          const_name = nil
        when 1
          const_name = hash.keys[0]
          prerequisites = hash[const_name]
        else
          raise ArgumentError, "multiple task names specified: #{hash.keys.inspect}"
        end
      end

      if const_name.nil?
        raise ArgumentError, "no constant name specified"
      end
      
      case prerequisites
      when nil
      when String
        prerequisites = Utils.shellsplit(prerequisites)
      when Array
        argv = []
        prerequisites.each do |prereq|
          argv << '-!'
          argv << prereq.to_s
        end
        prerequisites = argv
      else
        prerequisites = ['-!', prerequisites.to_s]
      end
      
      [const_name, prerequisites]
    end
  end
end