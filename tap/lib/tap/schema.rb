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
    
    def initialize(schema={})
      schema = symbolize(schema)
      
      @tasks = hashify(schema[:tasks] || {})
      @joins = dehashify(schema[:joins] || [])
      @queue = dehashify(schema[:queue] || [])
      @middleware = dehashify(schema[:middleware] || [])
    end
    
    def normalize!(references=REFERENCES)
      derefs = {}
      references.each_pair do |ref, block|
        derefs[ref] = block.call
      end
      
      tasks.dup.each_pair do |key, task|
        tasks[key] = normalize(task, derefs) do |id, data| 
          yield(:task, id || key, data)
        end
      end
      
      joins.collect! do |join|
        normalize(join, derefs) do |id, data|
          yield(:join, id || :join, data)
        end
      end
      
      middleware.collect! do |m|
        normalize(m, derefs) do |id, data|
          yield(:middleware, id, data)
        end
      end
    end
    
    def build(app)
      errors = []
      
      # instantiate tasks
      tasks = {}
      arguments = {}
      self.tasks.each_pair do |key, task|
        begin
          instance, args = instantiate(task, app)
        
          tasks[key] = instance
          arguments[key] = args
        rescue
          errors << $!.message
          tasks[key] = nil
        end
      end
      
      # build the workflow
      self.joins.each do |join|
        begin
          inputs, outputs, instance = instantiate(join, app)
          
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
      
      # utilize middleware
      self.middleware.each do |middleware|
        instantiate(middleware, app)
      end
      
      unless errors.empty?
        raise BuildError.new(errors)
      end
      
      # enque tasks
      self.queue.each do |(task, inputs)|
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
    
    class BuildError < StandardError
      attr_reader :errors
      def initialize(errors)
        prefix = if errors.length > 1
          "#{errors.length} build errors\n"
        else
           ""
        end

        super "#{prefix}#{errors.join("\n")}\n"
      end
    end
  end
end