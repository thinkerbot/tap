require 'tap/schema/utils'
require 'tap/schema/parser'

module Tap
  class Schema
    class << self
      def load(str)
        new(YAML.load(str) || {})
      end
      
      def load_file(path)
        load(File.read(path))
      end
    end
    
    include Utils
    
    REFERENCES = {
      :stdin =>  lambda { $stdin },
      :stdout => lambda { $stdout },
      :stderr => lambda { $stderr },
      :env =>    lambda { Tap::Env.instance },
      :app =>    lambda { Tap::App.instance }
    }
    
    attr_reader :tasks
    
    attr_reader :joins
    
    attr_reader :queue
    
    attr_reader :middleware
    
    attr_reader :references
    
    def initialize(schema={}, references=REFERENCES)
      schema = schema.inject({
        :tasks => {},
        :joins => [],
        :queue => [],
        :middleware => []
      }) do |hash, (key, value)|
        hash[key.to_sym || key] = value
        hash
      end
      
      @tasks = hashify schema[:tasks]
      @joins = dehashify schema[:joins]
      @queue = dehashify schema[:queue]
      @middleware = dehashify schema[:middleware]
    end
    
    def build(app)
      return build(app) do |type, metadata| 
        metadata[:class]
      end unless block_given?
      
      schema = to_hash
      errors = []
      
      # instantiate tasks
      tasks = {}
      arguments = {}
      schema[:tasks].each_pair do |key, task|
        task = symbolize(task)
        begin
          klass = yield(:task, task)
          instance, args = instantiate(klass, task, app)
        
          tasks[key] = instance
          arguments[key] = args
        rescue
          errors << $!.message
          tasks[key] = nil
        end
      end
      
      # build the workflow
      schema[:joins].each do |join|
        join = symbolize(join)
        begin
          klass = yield(:join, join)
          inputs, outputs, instance = instantiate(klass, join, app)
          
          inputs = inputs.collect do |key| 
            unless task = tasks[key]
              unless tasks.has_key?(key)
                errors << "missing join input: #{key.inspect}"
              end
            end
            task
          end
          
          outputs = outputs.collect do |key| 
            unless task = tasks[key]
              unless tasks.has_key?(key)
                errors << "missing join output: #{key.inspect}"
              end
            end
            task
          end
          
          instance.join(inputs, outputs) if errors.empty?
        rescue
          errors << $!.message
        end
      end
      
      # utilize middleware (future)
      # schema.middleware.each do |middleware|
      #   middleware = instantiate(middleware) do |metadata|
      #     yield(:middleware, metadata)
      #   end
      #   
      #   use middleware
      # end
      
      unless errors.empty?
        prefix = if errors.length > 1
          "#{errors.length} build errors\n"
        else
          ""
        end
        
        raise "#{prefix}#{errors.join("\n")}\n"
      end
      
      # enque tasks
      schema[:queue].each do |(task, inputs)|
        unless inputs
          inputs = arguments[task]
        end
        
        app.enq(tasks[task], *inputs) if inputs
      end
      
      tasks
    end
    
    # Creates an hash dump of self.
    def to_hash
      { :tasks => tasks, 
        :joins => joins, 
        :queue => queue, 
        :middleware => middleware
      }
    end
    
    # Converts self to a hash and serializes it to YAML.
    def dump
      YAML.dump(to_hash)
    end
    
    # helper to instantiate a class from metadata
    def instantiate(klass, data, app) # :nodoc:
      case data
      when Array then klass.parse!(data, app)
      when Hash  then klass.instantiate(data, app)
      end
    end
  end
end