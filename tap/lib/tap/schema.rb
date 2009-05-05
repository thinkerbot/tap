autoload(:Shellwords, 'shellwords')

module Tap
  class Schema
    autoload(:Parser, 'tap/schema/parser')
    
    class << self
      def parse(argv=ARGV)
        Parser.new(argv).schema
      end

      def load(str)
        new(YAML.load(str) || {})
      end
      
      def load_file(path)
        load(File.read(path))
      end
    end
    
    attr_reader :tasks
    
    attr_reader :joins
    
    attr_reader :queue
    
    def initialize(schema={})
      schema = schema.inject({
        :tasks => {},
        :joins => [],
        :queue => []
      }) do |hash, (key, value)|
        hash[key.to_sym || key] = value
        hash
      end
      
      @tasks = schema[:tasks]
      @joins = dehashify schema[:joins]
      @queue = dehashify schema[:queue]
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
        raise errors.join("\n")
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
      { :tasks => hashify(tasks), 
        :joins => joins, 
        :queue => queue
      }
    end
    
    # Converts self to a hash and serializes it to YAML.
    def dump
      YAML.dump(to_hash)
    end
    
    protected
    
    # helper to instantiate a class from metadata
    def instantiate(klass, data, app) # :nodoc:
      case data
      when Array then klass.parse!(data, app)
      when Hash  then klass.instantiate(data, app)
      end
    end
    
    def sorted_each(hash) # :nodoc:
      hash.keys.sort.each do |key|
        yield(hash[key])
      end
    end
    
    def symbolize(hash) # :nodoc:
      return hash unless hash.kind_of?(Hash)
      
      hash.inject({}) do |opts, (key, value)|
        opts[key.to_sym || key] = value
        opts
      end
    end
    
    def dehashify(obj) # :nodoc:
      case obj
      when Hash 
        obj.keys.sort.collect do |key|
          obj[key]
        end
      else      
        obj
      end
    end
    
    def hashify(obj) # :nodoc:
      case obj
      when Hash 
        obj
      else      
        obj.inject({}) do |hash, entry|
          hash[hash.length] = entry
          hash
        end
      end
    end
  end
end