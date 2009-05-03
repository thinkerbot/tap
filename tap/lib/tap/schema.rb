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