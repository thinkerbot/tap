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
    
    def add(task, inputs=nil)
      collect_tasks(task).collect do |task|
        tasks[task] = stringify(task.to_hash)
        task.joins
      end.flatten.uniq.each do |join|
        joins << [join.inputs, join.outputs, stringify(join.to_hash)]
      end
      
      if inputs
        queue << [task, inputs]
      end
      
      self
    end
    
    # Renames the current_key task to new_key.  References in joins and
    # queue are updated by rename.  Raises an error if built? or if the
    # specified task does not exist.
    def rename(current_key, new_key)
      if built?
        raise "cannot rename if built"
      end
      
      # rename task
      unless task = tasks.delete(current_key)
        raise "unknown task: #{current_key.inspect}"
      end
      tasks[new_key] = task
      
      # update join references
      joins.each do |inputs, outputs, join|
        inputs.each_index do |index|
          inputs[index] = new_key if inputs[index] == current_key
        end
        
        outputs.each_index do |index|
          outputs[index] = new_key if outputs[index] == current_key
        end
      end
      
      # update queue references, note both array and 
      # reference-style entries must be handled
      queue.each_index do |index|
        if queue[index].kind_of?(Array)
          if queue[index][0] == current_key
            queue[index][0] = new_key
          end
        else
          if queue[index] == current_key
            queue[index] = new_key
          end
        end
      end
      
      self
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
      tasks.freeze
      
      # build the workflow
      joins.collect! do |inputs, outputs, join|
        inputs = inputs.collect {|key| tasks[key] }
        outputs = outputs.collect {|key| tasks[key] }
        instantiate(join, app).join(inputs, outputs)
      end
      joins.freeze
      
      # utilize middleware
      middleware.collect! do |middleware|
        instantiate(middleware, app)
      end
      middleware.freeze
      
      # enque tasks
      queue.each do |(key, inputs)|
        app.enq(tasks[key], *inputs)
      end
      queue.clear.freeze
      
      @app = app
      self
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
    
    protected
    
    # helper to collect all tasks and tasks joined to task
    def collect_tasks(task, collection=[]) # :nodoc:
      unless collection.include?(task)
        collection << task
        
        task.joins.each do |join|
          (join.inputs + join.outputs).each do |input|
            collect_tasks(input, collection)
          end
        end
      end
      
      collection
    end
  end
end