require 'tap/workflow'
require 'tap/env'
require 'tap/declarations/description'
require 'tap/tasks/singleton'

module Tap
  module Declarations
    def self.extended(base)
      base.instance_variable_set(:@desc, nil)
      base.instance_variable_set(:@baseclass, Tap::Task)
      base.instance_variable_set(:@namespace, Object)
    end
    
    # Sets the description for use by the next task declaration.
    def desc(str)
      @desc = Lazydoc.register_caller(Description)
      @desc.desc = str
      @desc
    end
    
    def baseclass(clas)
      previous_baseclass = @baseclass
      begin
        @baseclass = clas
        yield
      ensure
        @baseclass = previous_baseclass
      end
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
    
    def task(name, configs={}, clas=@baseclass, &block)
      @desc ||= Lazydoc.register_caller(Description)
      name, prerequisites = parse(name)

      if prerequisites.nil?
        return declare(clas, name, configs, &block)
      end

      desc = @desc
      tasc = work(name, configs) do |workflow|
        prereqs = prerequisites.collect {|prereq| init(prereq) }
        obj     = init("#{name}/task", workflow.config.to_hash)

        setup = lambda do |input|
          prereqs.each {|prereq| exe(prereq, []) }
          exe(obj, input)
        end

        [setup, obj]
      end

      @desc = desc
      namespace(name) do
        declare(clas, 'Task', configs, &block)
      end

      tasc
    end

    def work(name, configs={}, clas=Tap::Workflow, &block)
      @desc ||= Lazydoc.register_caller(Description)
      task(name, configs, clas, &block)
    end

    private

    def parse(const_name)
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

      unless prerequisites.nil? || prerequisites.kind_of?(Array)
        prerequisites = [prerequisites]
      end

      [const_name, prerequisites]
    end
  end
end