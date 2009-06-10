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
    # to be added to an application during build.  A key may be specified
    # alone if tasks[key] is an array; in that case, the arguments remaining
    # in tasks[key] after instantiation will be used.
    #
    #   queue:
    #   - key                  # uses tasks[key]
    #   - [key, [1, 2, 3]]     # enques tasks[key] with [1, 2, 3]
    #
    attr_reader :queue
    
    # An array of middleware to build onto the app.
    attr_reader :middleware
    
    # The app used to build self
    attr_reader :app
    
    def initialize(schema={})
      @tasks = schema['tasks'] || {}
      @joins = schema['joins'] || []
      @queue = schema['queue'] || []
      @middleware = schema['middleware'] || []
      
      @app = nil
    end
    
    def resolve!
      tasks.each_pair do |key, task|
        task ||= {}
        tasks[key] = resolve(task) do |id|
          yield(:task, id || key)
        end
      end
      
      joins.collect! do |inputs, outputs, join|
        join ||= {}
        join = resolve(join) do |id|
          yield(:join, id || 'join')
        end
        [inputs, outputs, join]
      end
      
      middleware.collect! do |m|
        resolve(m) do |id|
          yield(:middleware, id)
        end
      end
      
      queue.collect! do |(key, inputs)|
        [key, inputs || tasks[key]]
      end
      
      self
    end
    
    def validate!
      errors = []
      tasks.each_value do |task|
        unless resolved?(task)
          errors << "unresolvable task: #{task.inspect}"
        end
      end
      
      joins.each do |inputs, outputs, join|
        unless resolved?(join)
          errors << "unresolvable join: #{join.inspect}"
        end
        
        inputs.each do |key| 
          unless tasks.has_key?(key)
            errors << "missing join input: #{key.inspect}"
          end
        end
        
        outputs.each do |key| 
          unless tasks.has_key?(key)
            errors << "missing join output: #{key.inspect}"
          end
        end
      end
      
      queue.each do |(key, args)| 
        if tasks.has_key?(key)
          unless args.kind_of?(Array)
            errors << "non-array args: #{args.inspect}"
          end
        else
          errors << "missing task: #{key}"
        end
      end
      
      middleware.each do |m|
        unless resolved?(m)
          errors << "unresolvable middleware: #{m.inspect}"
        end
      end
      
      unless errors.empty?
        prefix = if errors.length > 1
          "#{errors.length} schema errors\n"
        else
           ""
        end

        raise "#{prefix}#{errors.join("\n")}\n"
      end
      
      self
    end
    
    def cleanup!
      joins.delete_if do |inputs, outputs, join|
        
        # remove missing inputs
        inputs.delete_if  {|key| !tasks.has_key?(key) }
        
        # remove missing outputs
        outputs.delete_if {|key| !tasks.has_key?(key) }
        
        # remove orphan joins
        inputs.empty? || outputs.empty?
      end
      
      # remove inputs without a task
      queue.delete_if do |(key, inputs)|
        !tasks.has_key?(key)
      end
      
      self
    end
    
    def build!(app, validate=true)
      validate! if validate
      
      # instantiate tasks
      tasks.each_pair do |key, task|
        tasks[key] = instantiate(task, app)
      end
      
      # build the workflow
      joins.collect! do |inputs, outputs, join|
        inputs = inputs.collect {|key| tasks[key] }
        outputs = outputs.collect {|key| tasks[key] }
        instantiate(join, app).join(inputs, outputs)
      end
      
      # utilize middleware
      middleware.collect! do |middleware|
        instantiate(middleware, app)
      end
      
      # enque tasks
      queue.each do |(key, inputs)|
        app.enq(tasks[key], *inputs)
      end
      
      @app = app
      tasks
    end
    
    def built?
      @app != nil
    end
    
    def enque(key, *inputs)
      unless built?
        raise "cannot enque unless built"
      end
      
      unless task = tasks[key]
        raise "unknown task: #{key.inspect}"
      end
      
      app.queue.enq(task, inputs)
      task
    end
    
    # Creates an hash dump of self.
    def to_hash
      { 'tasks' => tasks, 
        'joins' => joins, 
        'queue' => queue, 
        'middleware' => middleware
      }
    end
    
    # Converts self to a hash and serializes it to YAML.
    def dump(io=nil)
      YAML.dump(to_hash, io)
    end
  end
end