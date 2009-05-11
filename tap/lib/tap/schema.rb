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
      @joins = dehashify(schema[:joins] || []).collect do |join|
        if join.kind_of?(Hash)
          join = symbolize(join)
          [join[:inputs], join[:outputs], join[:join]]
        else
          join
        end
      end
      @queue = dehashify(schema[:queue] || []).collect do |queue|
        if queue.kind_of?(Hash)
          queue = symbolize(queue)
          [queue[:id], queue[:args]]
        else
          queue
        end
      end
      @middleware = dehashify(schema[:middleware] || [])
    end
    
    # Clears all components of self.
    def clear
      to_a.each {|component| component.clear }
    end
    
    # True if all components of self are empty.
    def empty?
      to_a.all? {|component| component.empty? }
    end
    
    # True if all the instantiable components of self can be instantiated.
    def resolved?
      tasks.all? do |(key, task)|
        instantiable?(task)
      end &&
      joins.all? do |inputs, outputs, join|
        instantiable?(join)
      end &&
      middleware.all? do |m|
        instantiable?(m)
      end
    end
    
    def resolve!(references={})
      tasks.dup.each_pair do |key, task|
        task ||= {}
        tasks[key] = resolve(task, references) do |id, data|
          yield(:task, id || key, data)
        end
      end
      
      joins.collect! do |inputs, outputs, join|
        join ||= {}
        join = resolve(join, references) do |id, data|
          yield(:join, id || 'join', data)
        end
        [inputs, outputs, join]
      end
      
      middleware.collect! do |m|
        resolve(m, references) do |id, data|
          yield(:middleware, id, data)
        end
      end
      
      self
    end
    
    def valid?
      errors.empty?
    end
    
    def validate!
      errs = errors
      unless errs.empty?
        raise BuildError.new(errs)
      end
    end
    
    def errors
      errors = []
      tasks.each do |key, task|
        unless instantiable?(task)
          errors << "unknown task: #{task}"
        end
      end
      
      joins.each do |inputs, outputs, join|
        unless instantiable?(join)
          errors << "unknown join: #{join}"
        end
        
        inputs.each do |key| 
          unless tasks.has_key?(key)
            errors << "missing join input: #{key}"
          end
        end
        
        outputs.each do |key| 
          unless tasks.has_key?(key)
            errors << "missing join output: #{key}"
          end
        end
      end
      
      middleware.each do |m|
        unless instantiable?(m)
          errors << "unknown middleware: #{m}"
        end
      end
      
      errors
    end
    
    def build(app)
      # instantiate tasks
      tasks = {}
      arguments = {}
      self.tasks.each_pair do |key, task|
        instance, args = instantiate(task, app)
      
        tasks[key] = instance
        arguments[key] = args
      end
      
      # build the workflow
      self.joins.each do |inputs, outputs, join|
        inputs = inputs.collect {|key| tasks[key] }
        outputs = outputs.collect {|key| tasks[key] }
        instantiate(join, app).join(inputs, outputs)
      end
      
      # utilize middleware
      self.middleware.each do |middleware|
        instantiate(middleware, app)
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
    
    def traverse
      map = {}
      self.tasks.each_pair do |key, task|
        map[key] = [[],[]]
      end
      
      index = 0
      self.joins.each do |inputs, outputs, join|
        inputs.each do |key|
          map[key][1] << index
        end
        
        outputs.each do |key|
          map[key][0] << index
        end
        
        index += 1
      end
      
      map.keys.sort.collect do |key|
        [key, *map[key]]
      end
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