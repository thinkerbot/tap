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
    
    attr_reader :nodes
    
    attr_reader :joins
    
    attr_reader :queue
    
    def initialize(schema={})
      schema = schema.inject({
        :nodes => {},
        :joins => [],
        :queue => []
      }) do |hash, (key, value)|
        hash[key.to_sym || key] = value
        hash
      end
      
      @nodes = schema[:nodes]
      @joins = dehashify schema[:joins]
      @queue = dehashify schema[:queue]
    end
    
    def build(app)
      return build(app) do |type, metadata| 
        metadata[:class]
      end unless block_given?
      
      schema = to_hash
      errors = []
      
      # instantiate nodes
      nodes = {}
      arguments = {}
      schema[:nodes].each_pair do |key, node|
        node = symbolize(node)
        begin
          klass = yield(:task, node)
          instance, args = instantiate(klass, node, app)
        
          nodes[key] = instance
          arguments[key] = args
        rescue
          errors << $!.message
          nodes[key] = nil
        end
      end
      
      # build the workflow
      schema[:joins].each do |join|
        join = symbolize(join)
        begin
          klass = yield(:join, join)
          inputs, outputs, instance = instantiate(klass, join, app)
          
          inputs = inputs.collect do |key| 
            unless node = nodes[key]
              unless nodes.has_key?(key)
                errors << "missing input node: #{key.inspect}"
              end
            end
            node
          end
          
          outputs = outputs.collect do |key| 
            unless node = nodes[key]
              unless nodes.has_key?(key)
                errors << "missing output node: #{key.inspect}"
              end
            end
            node
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
      
      # enque nodes
      schema[:queue].each do |(node, inputs)|
        unless inputs
          inputs = arguments[node]
        end
        
        app.enq(nodes[node], *inputs) if inputs
      end
      
      nodes
    end
    
    # Creates an hash dump of self.
    def to_hash
      { :nodes => hashify(nodes), 
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