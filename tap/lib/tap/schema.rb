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
    
    # A hash of task schema describing individual tasks in a workflow.  Tasks
    # only require a class, but may contain configurations and even arguments
    # for enque.  Individual tasks may be a hash or an array.  The tasks are
    # resolved if they take one of these forms:
    #
    #   tasks:
    #     key: {:class: TaskClass, ...}
    #     key: [TaskClass, ...]
    #   
    attr_reader :tasks
    
    # An array of join schema that describe how to join tasks together.  Joins
    # have arrays of inputs and outputs that reference task keys.  Individual
    # joins may be a hash or an array.  The joins are resolved if they take
    # one of these forms:
    #
    #   joins:
    #   - [[inputs], [outputs], {:class: JoinClass, ...}]
    #   - [[inputs], [outputs], [JoinClass, ...]]
    #
    attr_reader :joins
    
    # An array of [key, [args]] data that indicates the tasks and arguments
    # to be added to an application during build.  If args are not specified,
    # then the arguments specified in the task schema are used.
    #
    #   queue:
    #   - key                  # uses tasks[key] arguments
    #   - [key, [1, 2, 3]]     # enques tasks[key] with [1, 2, 3]
    #
    attr_reader :queue
    
    # An array of middleware to build onto the app.
    attr_reader :middleware
    
    def initialize(schema={})
      schema = symbolize(schema)
      
      @tasks = hashify(schema[:tasks] || {})
      @joins = schema[:joins] || []
      @queue = schema[:queue] || []
      @middleware = schema[:middleware] || []
    end
    
    # Clears all components of self.
    def clear
      to_a.each {|component| component.clear }
    end
    
    # True if all components of self are empty.
    def empty?
      to_a.all? {|component| component.empty? }
    end
    
    # True if the schema is able to be built.
    def resolved?
      tasks.all? do |(key, task)|
        case task
        when Hash  then task[:class].kind_of?(Class)
        when Array then task[0].kind_of?(Class)
        else false
        end
      end &&
      joins.all? do |inputs, outputs, join|
        case join
        when Hash  then join[:class].kind_of?(Class)
        when Array then join[0].kind_of?(Class)
        else false
        end
      end
    end
    
    def resolve!(references={})
      tasks.dup.each_pair do |key, task|
        tasks[key] = normalize(task, references) do |id, data|
          yield(:task, id || key, data)
        end
      end
      
      joins.collect! do |inputs, outputs, join|
        join = normalize(join || ['join'], references) do |id, data|
          yield(:join, id, data)
        end
        [inputs, outputs, join]
      end
      
      middleware.collect! do |m|
        normalize(m, references) do |id, data|
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
      self.joins.each do |inputs, outputs, join|
        begin
          instance = instantiate(join, app)
          
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
    
    # Creates an array of [tasks, joins, queue, middleware]
    def to_a
      [tasks, joins, queue, middleware]
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